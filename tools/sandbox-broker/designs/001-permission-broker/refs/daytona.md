# Daytona

## Summary

Daytona is a multi-tenant sandbox-as-a-service platform: per-agent OCI containers (full kernel/FS/net stack) provisioned in ~90ms, driven over HTTP/SDK/CLI/MCP. It operates a **layer above** our broker — instead of mediating syscalls inside an existing process, it spins up a disposable computer per agent task and exposes a REST/Toolbox API to drive it. Useful as study material for the workspace lifecycle, GC cron pattern, network egress policy, and agent control surface (especially the in-sandbox `daemon` Toolbox API).

## Architecture

Three planes (control / interface / compute):

- **Control plane** — `apps/api` (NestJS, TypeORM, Postgres, Redis). Owns sandbox state machine, scheduling, GC cron jobs, RBAC, billing.
- **Compute plane** — `apps/runner` (Go, Gin). Talks to local Docker, manages iptables, lifecycle of containers on one node. Pulled by API via `runner-adapter`.
- **In-sandbox daemon** — `apps/daemon` (Go, Gin) baked into every snapshot image. Exposes the **Toolbox API** the agent actually drives (process exec, fs, git, lsp, computer-use, pty, ports).
- **Edge** — `apps/proxy` (preview URLs), `apps/ssh-gateway`, `apps/snapshot-manager`.
- **Clients** — Python/TS/Ruby/Go/Java SDKs in `libs/`, plus a stdio MCP server in `apps/cli/mcp`.

Adapter pattern: API → `RunnerAdapterFactory` → v0/v2 (`apps/api/src/sandbox/runner-adapter/`) so it can target multiple runner generations.

## Workspace Model

Sandbox = OCI container on a runner. Defined in `apps/api/src/sandbox/entities/sandbox.entity.ts`:

- Identity: `id` (uuid), `organizationId`, `name`, `region`, `class` (SMALL/…)
- Image: `snapshot` (image ref) or `buildInfo` (declarative builder)
- Resources: `cpu` (default 2), `mem` (4 GiB), `disk` (10), `gpu` (0)
- State machine: `state` × `desiredState` (started/stopped/archived/destroyed/…). Reconciler drives `state → desiredState`.
- Network: `networkBlockAll: bool`, `networkAllowList: string` (CSV CIDRs)
- Mounts: `volumes: SandboxVolume[]` (jsonb)
- Auth: per-sandbox `authToken` (nanoid 32) used by API → daemon and proxy
- Lifecycle timers: `autoStopInterval` (15 min idle), `autoArchiveInterval` (7 days stopped), `autoDeleteInterval` (-1 = off)

Provisioning (`apps/runner/pkg/docker/create.go:26`): pull image → arch validate → create container with computed config → start → fire-and-forget goroutines apply iptables (allow-list / block-all / egress-mark). Daemon-readiness checked via `waitForDaemonRunning` (HTTP probe to in-container daemon).

Tear down: soft-delete in DB (`getSoftDeleteUpdate`), reconciler eventually issues runner destroy.

## Policy / Config

Per-sandbox configurables (DTO + entity):

- Image: `snapshot` ref, or declarative `BuildInfo` (Dockerfile-equivalent hash-keyed)
- Resources: cpu/mem/disk/gpu, `class`
- Env: `env: jsonb`, `labels: jsonb`
- Public/preview: `public: bool`, custom preview proxy
- **Network**: `networkBlockAll` OR `networkAllowList` (CSV CIDRs validated by `validateNetworkAllowList`); plus a metadata key `limitNetworkEgress=true` that adds an iptables MARK for tc shaping.
- Volumes (named, with mount-path validation `validateMountPaths`/`validateSubpaths`)
- Org-level limits: per-region quota, per-sandbox limits (`getEffectivePerSandboxLimits`), audit logs

Notably absent: there is **no per-syscall, per-tool, or per-command policy**. Once inside the sandbox, the agent is root-equivalent. Isolation is the container boundary plus iptables. Our broker operates at exactly the layer Daytona doesn't.

## Agent Integration

Three surfaces:

1. **REST API** (`apps/api`) — sandbox lifecycle. Bearer API key. e.g. `POST /api/sandbox`.
2. **Toolbox API** (`apps/daemon/pkg/toolbox/server.go`) — the API the agent actually uses post-create. Routed through API or proxy via the per-sandbox `authToken`. Endpoints under `/process`, `/fs`, `/git`, `/lsp`, `/computeruse`, `/pty`, `/port`, `/proxy`. SDK methods like `sandbox.process.code_run(...)` translate to Toolbox calls.
3. **MCP server** (`apps/cli/mcp/server.go`) — stdio MCP exposing `create_sandbox`, `destroy_sandbox`, `execute_command`, `upload_file`, `download_file`, `git_clone`, `list_files`, `preview_link`, etc. Drop-in for Claude Code/Cursor.

Each SDK is auto-generated from OpenAPI (see `libs/api-client*` and `libs/toolbox-api-client*`).

## CLI / UX

`apps/cli` (Go, Cobra). Subcommands: `auth`, `sandbox {create,list,info,start,stop,delete,exec,ssh,preview-url,archive}`, `snapshot`, `volume`, `organization`, `mcp`, `autocomplete`, `docs`. Defaults: `daytona create` builds a sandbox from the org default snapshot/region with class SMALL. The CLI is a thin shell over the Go API client.

## Failure Modes

- **Reconciler-driven**: the API runs `@Cron(EVERY_10_SECONDS)` jobs `auto-stop-check` / `auto-archive-check` / `auto-delete-check` / `draining-runner-sandboxes-check` (`apps/api/src/sandbox/managers/sandbox.manager.ts:90+`). Each holds a Redis lock to single-flight per-cluster.
- **Orphaned containers**: Runner exposes `recover.go` / `recover_from_storage_limit.go`; sandbox pending bit + state-vs-desiredState gap means a crashed reconciler turn just gets retried 10s later.
- **Crashed runner**: `prevRunnerId` tracked on sandbox so reassignment can fall back. Dedicated `findAllReady()` filters runner pool.
- **Network partition during create**: `SkipStart` flag plus `errdefs.IsConflict` swallow on duplicate `ContainerCreate` keep create idempotent.
- **Snapshot-pull-in-flight**: `Create` polls every 1s up to `snapshotPullTimeout` rather than racing.
- **iptables persistence**: `netrules` runs a 1-min ticker writing `iptables-save > /etc/iptables/rules.v4` so reboots don't drop allow-lists.

## Notable Design Ideas

- **Desired-state reconciler with single-flight Redis locks** — every state change is `(state, desiredState, pending)` in Postgres, and 10s cron loops drive convergence. Crash-tolerant by construction. Worth borrowing for any broker that must survive its own restart.
- **Per-sandbox auth token (nanoid 32)** — API mints a token at create time and embeds it in the container env; daemon and proxy verify it. Removes a class of cross-sandbox CSRF/escape issues without per-call signing.
- **Iptables chain-per-container with `DAYTONA-SB-` prefix** (`apps/runner/pkg/netrules/`) — chains scoped by name make GC trivially safe (`ListDaytonaChains` + `ClearAndDeleteChain`). Lessons for any allow-list implementation: namespace your chains, reconcile on a timer, persist explicitly.
- **Two-axis allow-list: CIDR allowlist OR block-all OR egress-rate-mark** layered as separate iptables tables (`filter` for ACL, `mangle` for shaping). Composable by table, not by rule.
- **Adapter layer for runner versions** — `RunnerAdapterFactory` lets the control plane evolve faster than the data plane. We could mirror this for "broker protocol v1 vs v2" to avoid lockstep upgrades of agents.
- **Toolbox API as a uniform agent surface** — one HTTP API for fs+process+lsp+pty unifies what is otherwise N transports. If we ever expose a remote broker, copying this carving (fs/process/git/lsp) reduces SDK design effort.

## Anti-Patterns / Caveats

- **No in-sandbox policy**: agents inside a sandbox are root with full network (modulo iptables) and full FS. The model assumes "blast radius = container", which is fine for isolated workloads but doesn't help local developer machines — exactly our use case.
- **Heavy infra**: Postgres + Redis + N runners + dashboard + proxy + ssh-gateway + snapshot-manager + otel-collector. Operational footprint is enormous compared to a unix daemon broker. Don't drift toward this for personal-machine tooling.
- **Goroutine fire-and-forget for net rules** (`create.go:159-181`) — if SetNetworkRules fails, the sandbox is already running and traffic is unrestricted until next reconcile. Avoid this in security-critical paths; fail closed.

## Key File Pointers

- `apps/api/src/sandbox/entities/sandbox.entity.ts:52` — sandbox schema (state machine + auto-* timers)
- `apps/api/src/sandbox/managers/sandbox.manager.ts:90` — reconciler crons (auto-stop / archive / delete / drain)
- `apps/api/src/sandbox/managers/sandbox-actions/` — start/stop/destroy/archive action commands
- `apps/api/src/sandbox/runner-adapter/runnerAdapter.ts` — control-plane → data-plane abstraction
- `apps/api/src/sandbox/utils/network-validation.util.ts:12` — CIDR allow-list validator
- `apps/runner/pkg/docker/create.go:26` — provisioning sequence (pull → create → start → netrules)
- `apps/runner/pkg/netrules/netrules.go:19` — `NetRulesManager` (mutex + iptables + persistence loop)
- `apps/runner/pkg/netrules/set.go:9` — `SetNetworkRules` (allow-list chain + DROP-all default)
- `apps/runner/pkg/netrules/limiter.go:9` — egress-rate MARK (mangle table)
- `apps/daemon/pkg/toolbox/server.go:55` — in-sandbox Toolbox API config (process/fs/git/lsp/computeruse/pty)
- `apps/cli/mcp/server.go` + `apps/cli/mcp/tools/` — MCP server exposing sandbox CRUD + fs/exec to agents
- `apps/cli/cmd/sandbox/create.go:24` — CLI surface (`daytona create`)
