# Windmill (NSJail integration)

## Summary

Windmill is a serverless workflow / script-runner platform. The piece relevant to us is its per-job sandbox: every script execution can be wrapped in [google/nsjail](https://github.com/google/nsjail) using a hand-written `*.config.proto` template per language. NSJail is the in-process primitive; Windmill itself owns lifecycle, timeout policy, and resource accounting.

## NSJail Integration

NSJail is invoked as a subprocess per job, not as a daemon. The Rust worker:

1. Picks a per-language template embedded at compile time via `include_str!` (e.g. `NSJAIL_CONFIG_RUN_PYTHON3_CONTENT`, see `backend/windmill-worker/src/python_executor.rs:118-119`).
2. String-substitutes placeholders (`{JOB_DIR}`, `{TIMEOUT}`, `{CLONE_NEWUSER}`, `{SHARED_MOUNT}`, `{SHARED_DEPENDENCIES}`, `{TRACING_PROXY_CA_CERT_PATH}`, `#{DEV}`, etc.).
3. Writes the rendered config to `<job_dir>/run.config.proto`.
4. Execs `nsjail --config run.config.proto -- <interpreter> <wrapper>` with `env_clear()` and a curated env (`PATH`, `BASE_INTERNAL_URL`, proxy vars).

Per-language templates live in `backend/windmill-worker/nsjail/`: separate protos for **run** vs **download/install/lock** phases for each of python3, bun, deno, ruby, rust, go, java, csharp, php, powershell, R, ansible, nu, bash. Phase split lets `download.*` use tight `rlimit_*` (e.g. python download `rlimit_as: 2048`) while `run.*` either reuses limits (python: `rlimit_as: 4096`) or sets `disable_rl: true` (bash, bun, deno, php, go, ruby-run).

## Policy / Resource DSL

The DSL is the upstream nsjail protobuf (`Nsjail.NsJailConfig`). What Windmill actually toggles per template:

- `time_limit: {TIMEOUT}` — wall clock seconds.
- `rlimit_as / rlimit_cpu / rlimit_fsize / rlimit_nofile` — per-language tuned (python run: 4096 MB AS / 1000s CPU / 1000 MB fsize / 10000 fds).
- `disable_rl: true` — opt-out for languages that need headroom.
- `mode: ONCE` — fork one job per invocation.
- `clone_newnet: false` — **network namespace is shared with host** (every template). Network restriction is delegated to HTTPS proxy env vars (`HTTP_PROXY`, MITM tracing proxy), not nsjail.
- `clone_newuser: {CLONE_NEWUSER}` — user namespace toggled by `DISABLE_NUSER` env (off in Docker-in-Docker, on otherwise).
- `mount_proc: true`, `iface_no_lo: true`, `keep_caps: false`, `keep_env: true`, `skip_setsid: true`.
- Bind mounts: `/bin /lib /lib64 /usr /etc /dev/{null,random,urandom}` read-only, `/tmp` as tmpfs (size capped, e.g. `size=500000000`), plus per-job mounts from `{JOB_DIR}` for `wrapper.*`, `args.json`, `result.json`, `main.<ext>`.
- `{SHARED_MOUNT}` and `{SHARED_DEPENDENCIES}` — Windmill-injected stanzas for inter-step shared dirs and pip wheel cache (read-only bind per `additional_python_paths` entry).
- Dev hook: `#{DEV}` is replaced with a `/nix/store` bind under `cfg(debug_assertions)` (`backend/windmill-worker/src/common.rs:53-65`).

Annotations: scripts can opt-in per-job with `#sandbox` / `// sandbox` comment annotations parsed as `BashAnnotations` / `PythonAnnotations`. If the annotation is set but `NSJAIL_AVAILABLE` is `None`, the job hard-fails (see `bash_executor.rs:88-93`, `python_executor.rs:620-625`). Global setting `force_sandboxing` and `JobIsolationLevel::{None, Unshare, NsjailSandboxing}` decide the default (`worker.rs:697-725`, `868-876`).

A separate `windmill-worker-volumes` crate adds named-volume mounts via `// volume: <name> <target>` annotations, capped at `MAX_VOLUMES_PER_JOB = 10`, with target whitelist `/tmp/, /mnt/, /opt/, /home/, /data/` and a name regex (`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,253}[a-zA-Z0-9]$`). See `backend/windmill-worker-volumes/src/lib.rs:13-134`.

## Worker → Sandbox Lifecycle

One nsjail process per job, `mode: ONCE`. No reuse, no pool. The worker:

1. Resolves an effective timeout = job timeout + 15 s buffer so `handle_child` can race nsjail's own `time_limit` (`common.rs:977-986`).
2. `start_child_process(nsjail_cmd, ...)` (`worker_utils.rs`) spawns it.
3. `handle_child` (`backend/windmill-worker/src/handle_child.rs:103+`) supervises: writes `oom_score_adj=1000` to make OOM target the job not the worker, polls memory peak from `/proc/<nsjail_pid>/task/<nsjail_pid>/children` (`get_mem_peak`, line 650+), watches log size (2 MB cap), timeout, and DB-driven cancellation. Kill cascade: SIGINT → SIGTERM → SIGKILL on the process tree.
4. On boot the worker runs `nsjail --help` once and caches `NSJAIL_AVAILABLE: Option<String>` (`worker.rs:505-547`); jobs requesting sandbox when unavailable fail fast.

## Recent AI-Sandbox Push

PR #8058 ("add sandbox annotations, volume mounts, for AI sandbox starting with claude") and the associated `sandbox-image/Dockerfile.sandbox` are the AI-agents-specific shipment. Concretely:

- A separate `Dockerfile.sandbox` (Debian + Determinate Nix + Nix `.#sandbox` profile) bakes **Claude Code CLI**, **`@openai/codex`**, **mermaid-cli**, Chromium-via-Nix, Postgres client, Puppeteer config, plus a UID 1000 `agent` user with passwordless sudo. This is the image launched as the per-job container; nsjail still wraps execution inside it.
- The `// volume: <name> <target>` annotation explicitly supports things like `// volume: agent-memory .claude` (lib.rs:408-412) — persistent agent state across runs, mounted into the sandbox.
- `ephemeral-backends/` (TypeScript) spawns whole Windmill backends per session using **bwrap** instead of nsjail (`spawn.ts:382-397`) — separate isolation layer for the parent process; nsjail still applies inside the job.

So the "AI sandbox" feature is mostly: bundled agent CLIs + named-volume persistence + the existing nsjail per-job pattern reused. No agent-specific policy DSL was added.

## Failure Modes

- **nsjail binary missing** at startup: `NSJAIL_AVAILABLE = None`, logged as ERROR. Jobs with `#sandbox` or `JobIsolationLevel::NsjailSandboxing` return `ExecutionErr` immediately.
- **nsjail exits non-zero**: surfaced as job error; stderr piped through `handle_child`.
- **Resource limit hit**: `rlimit_as` / fsize triggers SIGSEGV-style kill from nsjail; mem peak captured from `/proc`.
- **Timeout**: nsjail enforces `time_limit` itself, but worker's `handle_child` also races it with a 15 s shorter sleep so Windmill can attribute the kill and write a friendly cancel reason. SIGINT → SIGTERM → SIGKILL.
- **OOM**: worker pre-sets `/proc/<pid>/oom_score_adj=1000` so kernel OOM killer targets the job not the worker.
- **Log flood**: 2 MB stdout/stderr cap, then `KillReason::TooManyLogs`.

## Notable Design Ideas

- **One config per (language, phase)**. Splitting `download.*` from `run.*` lets you tighten limits during dependency resolution where you don't need user code's full quota.
- **Templates as embedded strings + placeholder substitution**. Trivially auditable, no runtime YAML/DSL parser. Compile-time `include_str!` makes them part of the binary.
- **Capability detection at boot**: `nsjail --help` probe → `Option<String>` → fail-fast on jobs that demand sandboxing.
- **Layered isolation**: `JobIsolationLevel` enum (None / Unshare / Nsjail) lets cheap PID-namespace-only isolation be the default while keeping nsjail behind a feature flag.
- **`oom_score_adj=1000`** to bias OOM kill toward the job. Cheap, effective.
- **Scope sandbox by mount, govern network by proxy**. `clone_newnet: false` everywhere, then route via `HTTP_PROXY` (and an EE MITM tracing proxy with CA cert bind-mounted into the jail).
- **Annotation-driven opt-in** (`#sandbox`, `// volume:`) keeps the sandbox decision in the script itself, in source.

## Anti-Patterns / Caveats

- **No per-job network policy.** Every template uses `clone_newnet: false`. If a script wants outbound restrictions you fall back to proxy env vars or external firewall — nsjail isn't doing it.
- **Templates are duplicated across languages** (~17 protos with mostly identical mount blocks). Drift risk: a fix to python template doesn't auto-propagate. Several already drifted on `rlimit` vs `disable_rl`.
- **`keep_env: true` + manual `env_clear()` in Rust.** The cleanliness of the env depends on the caller, not the jail; a misconfigured executor leaks host env.
- **`DISABLE_NSJAIL` defaults to `true`** in OSS (`worker.rs:340-343`), so the sandbox is opt-in — easy to deploy thinking it's on when it isn't.
- **AI-sandbox image grants `NOPASSWD:ALL` sudo to `agent`** (`sandbox-image/Dockerfile.sandbox`). Inside-jail privilege escalation is wide-open; isolation rests entirely on the nsjail wrapper, not the user.

## Key File Pointers

- `backend/windmill-worker/nsjail/` — all `.config.proto` templates (run/download/install/lock per language).
- `backend/windmill-worker/src/python_executor.rs:118-119, 939-1018` — template embed + nsjail spawn.
- `backend/windmill-worker/src/bash_executor.rs:85-249` — `#sandbox` annotation handling and nsjail vs unshare branching.
- `backend/windmill-worker/src/common.rs:53-65, 977-986` — `DEV_CONF_NSJAIL`, `resolve_nsjail_timeout`.
- `backend/windmill-worker/src/worker.rs:334-346, 505-547, 591, 697-725, 868-890` — `DISABLE_NSJAIL`/`DISABLE_NUSER`, `NSJAIL_AVAILABLE` boot probe, `NSJAIL_PATH`, `JobIsolationLevel`, `is_sandboxing_enabled`/`is_unshare_enabled`.
- `backend/windmill-worker/src/handle_child.rs:103-310, 650-720` — supervision, kill cascade, `get_mem_peak` reading nsjail's child via `/proc`.
- `backend/windmill-worker-volumes/src/lib.rs:13-207` — volume mount DSL and validation.
- `sandbox-image/Dockerfile.sandbox`, `sandbox-image/entrypoint.sh` — AI-agents image (Claude Code + Codex + mermaid + Nix).
- `ephemeral-backends/spawn.ts:382-397` — bwrap-based outer isolation for ephemeral Windmill backends.
- `debugger/nsjail.debug.config.proto` — debug-mode template.
- `CHANGELOG.md` refs: #7816 (`force_sandboxing` + `#sandbox`), #8058 (volume mounts + AI sandbox).
