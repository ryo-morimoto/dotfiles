# E2B (e2b-dev/infra)

## Summary

E2B is an open-source cloud platform that hands an AI agent a full Linux sandbox (Firecracker microVM on GCP/AWS, Nomad-scheduled) with file/process/port APIs. Note: this is **whole-VM isolation**, not in-process per-tool policy enforcement — orthogonal abstraction to our broker, but the session lifecycle / agent-facing API design transfers.

## Architecture

End-to-end flow (`packages/CLAUDE.md:99-107`):

```
Client → client-proxy → api (REST/Gin) ⟷ Postgres/Redis/Clickhouse
                          ↓
                       orchestrator (gRPC) ──► Firecracker microVMs ──► envd (in-VM, Connect-RPC :49983)
```

Modules:

- `packages/api/` — public REST surface (OpenAPI spec at `spec/openapi.yml`), JWT/Supabase auth, Postgres-backed.
- `packages/orchestrator/` — Firecracker lifecycle on each node. `pkg/sandbox/` (sandbox.go, fc/, network/, nbd/, uffd/, template/), `pkg/server/sandboxes.go` is the gRPC `SandboxService` impl. Requires sudo (Firecracker + nftables + netlink).
- `packages/envd/` — daemon shipped *inside* every VM. Chi router + Connect-RPC. Routes filesystem/process/cgroup RPCs locally.
- `packages/client-proxy/` — Consul-discovery edge that maps sandbox-id → orchestrator node.
- `packages/shared/pkg/grpc/{orchestrator,envd}` — generated proto stubs reused by API and orchestrator.

## Policy / Config Model

Policy lives entirely in `SandboxConfig` (`packages/orchestrator/orchestrator.proto:8-54`) and is set at *create time*; few things are enforced after boot.

- **Resource limits**: `vcpu`, `ram_mb`, `total_disk_size_mb`, `huge_pages`, `max_sandbox_length` (hours, hard upper bound on TTL).
- **Network egress** (`SandboxNetworkEgressConfig`, lines 75-80): `allowed_cidrs`, `denied_cidrs`, `allowed_domains`. Enforced via nftables sets + an egress proxy interface (`packages/orchestrator/pkg/sandbox/network/firewall.go:38-78`, `egressproxy.go:7-12`) — two pairs of allow/deny IP sets ("predefined" platform-wide and "user" per-sandbox) attached to a PREROUTE_FILTER chain. Domains require a TLS-MITM egress proxy (`CABundle()` injected into the VM).
- **Network ingress** (`SandboxNetworkIngressConfig`): optional `traffic_access_token` + `mask_request_host`.
- **Identity inside the VM**: `envd_access_token`, basic-auth username (envd `permissions/authenticate.go:14-28`). There is no per-syscall capability model — once authenticated, the user gets full process/fs RPC.
- **Volumes**: `SandboxVolumeMount{id,path,type,name}` mounted at boot.
- **Mutable post-create**: only `end_time` (timeout extension) and egress CIDR lists, via `SandboxUpdateRequest`.

## Workspace Model

- A sandbox is a Firecracker microVM cloned from a **template** (`template_id` + `build_id`). Templates are GCS-cached rootfs images (`packages/orchestrator/pkg/sandbox/template/`).
- Provisioning: `Create` rpc on the orchestrator. Server enforces `MaxSandboxesPerNode` and a `startingSandboxes` semaphore (`packages/orchestrator/pkg/server/sandboxes.go:105-128`) to bound concurrent boots. Returns a `client_id` (the orchestrator node) so client-proxy can route follow-ups.
- Snapshot/resume: `Pause` and `Checkpoint` RPCs serialize VM memory (uffd) + disk diff to GCS; `Create` with `snapshot=true` resumes. `auto_pause` and `auto_resume.policy` enable lazy resumption.
- Destruction: `Delete` runs a layered `Cleanup` (`packages/orchestrator/pkg/sandbox/cleanup.go`, used pervasively in `sandbox.go`) — registered LIFO closures release network slot, NBD device, rootfs, cgroup, FC process. `cleanup.AddPriority(sbx.Stop)` ensures the VM is killed first.
- Per-sandbox network slot (`pkg/sandbox/network/slot.go:24-58`) deterministically allocates host /32 + virtual /31 + tap interface from configured CIDRs (`10.11.0.0/16`, `10.12.0.0/16`).

## SDK / Agent Integration

Two-layer API surface:

1. **Public REST** (OpenAPI `spec/openapi.yml`): `POST /sandboxes`, `GET/POST/DELETE /sandboxes/{id}`, `/pause`, `/resume`, `/connect`, `/timeout`, `/network`, `/refreshes`, `/snapshots`, `/logs`, `/metrics`. SDKs (e2b-dev/E2B repo) are generated from this.
2. **In-VM RPC** (Connect-RPC over HTTP/2, port 49983, basic-auth):
   - `Filesystem` (`packages/envd/spec/filesystem/filesystem.proto`): `Stat`, `MakeDir`, `Move`, `ListDir`, `Remove`, `WatchDir` (server stream) + non-streaming `CreateWatcher`/`GetWatcherEvents`/`RemoveWatcher` poll variants.
   - `Process` (`packages/envd/spec/process/process.proto`): `Start` (stream), `Connect` (attach to existing), `List`, `SendInput`/`StreamInput`/`SendSignal`/`CloseStdin`, optional PTY.
   - File upload/download via plain HTTP routes mounted on the same chi router.
   - **Username carried over basic auth** maps to a real Linux user; commands run as that uid (`permissions/authenticate.go:30-47`).

Agents typically: `POST /sandboxes` → get an envd URL → open Connect-RPC streams for shell/fs.

## CLI / UX

The CLI lives in the sibling `e2b-dev/E2B` repo, not here. Surface-level: `e2b template build/list`, `e2b sandbox spawn/connect/list/kill`, `e2b auth login`. This repo's tooling is operator-side: `make build/{api,orchestrator}`, `make plan/apply` (Terraform), `make local-infra` (docker-compose Postgres/Redis/CH/Grafana), `make connect-orchestrator`.

## Failure Modes

- **VM crash / Firecracker exit**: orchestrator's `Cleanup` runs registered teardown (network slot release, NBD, rootfs unmount). `cleanup.AddPriority(sbx.Stop)` and `Sandboxes.NetworkReleased` callback (`pkg/server/sandboxes.go`) ensure slot is recycled.
- **Resource exhaustion**: `MaxSandboxesPerNode` LaunchDarkly flag → `codes.ResourceExhausted`; `startingSandboxes` semaphore → "too many starting" 4xx-equivalent. No queueing — clients retry.
- **Network partition** between orchestrator nodes: client-proxy uses Consul service discovery + Redis state to re-route. In-flight envd streams die; SDK reconnects via `/sandboxes/{id}/connect`.
- **Hung process**: envd `SendSignal` + idle `IdleTimeout` on the HTTP server. VM `max_sandbox_length` is the backstop.
- **Boot failure**: orchestrator `waitForEnvd` (`pkg/sandbox/sandbox.go:46`) probes envd HTTP health; failure triggers full cleanup chain.

## Notable Design Ideas

- **Cleanup-stack pattern**: every stateful resource registers a teardown closure during construction (`cleanup.Add` / `AddPriority`). Errors are joined, not lost. Cuts most "leaked tap interface / dangling NBD" classes of bug. Worth borrowing for our broker's per-session resource ownership.
- **Two-tier policy surface**: stable platform-wide `predefinedAllow/Deny` sets + per-session `userAllow/Deny` sets share one nftables chain. Lets the operator harden globally without rewriting per-session rules.
- **Config is the policy contract**: all enforceable knobs are proto fields on `SandboxConfig`; runtime mutation is restricted to `SandboxUpdateRequest` (only `end_time`, egress). Keeps the threat model small.
- **MMDS for in-VM bootstrap** (`packages/envd/internal/host/mmds.go`): envd reads sandbox-id/template-id/collector-addr from Firecracker's metadata service rather than CLI args — orchestrator can rotate identity without rebooting envd.
- **Connect-RPC over HTTP/2 with poll-or-stream watchers** (filesystem.proto:14-19): both streaming and non-streaming variants of `WatchDir`. Useful when an agent runtime can't hold long-lived streams.

## Anti-Patterns / Caveats

- **Coarse identity**: once an agent has the envd basic-auth creds it can `Process.Start` arbitrary commands as that uid. There is no per-call policy gate inside the VM — security relies on the VM boundary. Our broker can't borrow this: we don't have a VM.
- **Firecracker + sudo + nftables + netlink + NBD + uffd**: heavy operational footprint; only viable with Nomad/Terraform infra. Don't underestimate. Self-host story is GCP-only / AWS-beta.
- **No declarative policy file** (à la AppArmor/seccomp profiles per template). Templates carry rootfs but not capability profiles; operators encode policy in nftables predefined sets, deployed via Terraform.

## Key File Pointers

- `packages/orchestrator/orchestrator.proto:8-154` — `SandboxConfig`, network egress/ingress messages, `SandboxService` rpc surface.
- `packages/orchestrator/pkg/server/sandboxes.go:58-128` — Create flow with admission control.
- `packages/orchestrator/pkg/sandbox/sandbox.go:1-80,218-518` — sandbox struct and cleanup-stack lifecycle.
- `packages/orchestrator/pkg/sandbox/network/firewall.go:38-78` — nftables two-tier allow/deny sets.
- `packages/orchestrator/pkg/sandbox/network/slot.go:24-58` — deterministic per-slot IP/tap allocation.
- `packages/envd/main.go:132-204` — envd HTTP server wiring (chi + Connect-RPC + basic-auth middleware).
- `packages/envd/spec/filesystem/filesystem.proto`, `spec/process/process.proto` — in-VM agent API.
- `packages/envd/internal/permissions/{authenticate,path,user}.go` — username-as-identity model and home-dir-confined path resolution.
- `packages/envd/internal/host/mmds.go` — Firecracker MMDS bootstrap of identity.
- `spec/openapi.yml:1928-3122` — public sandbox REST surface.
- `CLAUDE.md` (repo root) — architecture summary maintained by the project itself.
