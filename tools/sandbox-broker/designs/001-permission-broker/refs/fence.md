# Fence (Use-Tusk)

## Summary

Fence is a Go CLI that wraps a target command in an OS-level sandbox (macOS Seatbelt or Linux bubblewrap+Landlock+seccomp) with a JSONC policy controlling network domains, filesystem paths, and command/SSH prefixes. It is **not** a long-running broker — it is a one-shot wrapper (`fence -- claude`) that, secondarily, can install per-agent hooks that re-pipe shell tool calls back through `fence -c` to enforce multi-token command denies.

## Architecture

Four layers, all in-process per `fence` invocation; no daemon.

1. **Config resolution** — `internal/config/`, `internal/templates/`, `internal/importer/`. Loads JSONC, resolves `extends` chain, merges templates and imported tool settings.
2. **Policy model** — `internal/config/config.go` types: `NetworkConfig`, `FilesystemConfig`, `DevicesConfig`, `CommandConfig`, `SSHConfig`, `MacOSConfig`, plus a `RuntimeExecPolicy` enum (`path`|`argv`).
3. **Runtime orchestration** — `internal/sandbox/manager.go`. Starts local HTTP + SOCKS5 filtering proxies (`internal/proxy/{http,socks}.go`), Linux `socat` Unix-socket bridges across the network namespace, validates shell, runs preflight command/SSH checks, generates a platform-specific wrapper command, and cleans up on exit.
4. **Platform enforcement** — `internal/sandbox/macos.go` generates Seatbelt profiles for `sandbox-exec`; `internal/sandbox/linux.go` generates `bwrap` invocations layered with optional Landlock (`linux_landlock.go`), seccomp (`linux_seccomp.go`), eBPF monitoring (`linux_ebpf.go`), and an argv-aware seccomp-user-notif exec supervisor (`runtime_exec_argv_linux.go`).

Public Go API in `pkg/fence/fence.go` exposes the same lifecycle for embedding.

## Policy / Config DSL

JSONC (`fence.jsonc` preferred, `fence.json` accepted) discovered upward from CWD, then `~/.config/fence/fence.{jsonc,json}` (legacy `~/Library/Application Support/fence/`, `~/.fence.json` honored). `extends` accepts a built-in template name (`code`, `code-relaxed`, `code-strict`, `git-readonly`, `local-dev-server`, `disable-telemetry`) or a relative path; `@base` reuses the user's resolved default. Slice fields append+dedupe; booleans OR; scalars and pointer-bools let the child win (`internal/config/config.go:686-816`).

Top-level keys: `network`, `filesystem`, `devices`, `command`, `ssh`, `macos`, `allowPty`, `forceNewSession`, `extends`. JSON Schema is generated from struct tags by `internal/configschema/` and published at `docs/schema/fence.schema.json` for editor completion.

Categories:

- **network**: `allowedDomains` (exact or `*.example.com`; `"*"` = relaxed mode), `deniedDomains`, `allowUnixSockets`, `allowAllUnixSockets`, `allowLocalBinding`, `allowLocalOutbound`, `allowLocalOutboundPorts` (Linux per-port host loopback bridges), `httpProxyPort`, `socksProxyPort`.
- **filesystem**: tiered `allowExecute` < `allowRead` < `allowWrite`, plus `denyRead`/`denyWrite`, `defaultDenyRead`, `strictDenyRead`, `allowGitConfig`. `denyWrite` always wins.
- **command**: `deny`, `allow` (overrides for specific deny patterns), `useDefaults` (built-in list of `shutdown`, `mkfs`, `chroot`, `dd if=`, …, see `config.go:127-166`), `runtimeExecPolicy: "path"|"argv"`, `acceptSharedBinaryCannotRuntimeDeny`. Prefix-matched, with a parser that understands `&&`, `||`, `;`, pipes, and nested `sh -c`/`bash -c`.
- **ssh**: separate first-class surface — `allowedHosts`, `deniedHosts`, `allowedCommands` (allowlist by default), `deniedCommands`, `allowAllCommands`, `inheritDeny`.
- **macos.mach.{lookup,register}**: trailing-`*` wildcards for Mach/XPC services.

The `code` template (`internal/templates/code.json`) is the canonical "AI agent" preset — allowlists ~30 LLM/registry/git domains, denies cloud-metadata IPs (169.254.169.254 etc.) and telemetry hosts, allows writes to CWD/`/tmp`/per-agent config dirs (`~/.claude/**`, `~/.codex/**`, …), denies reads of `~/.ssh/id_*`, `~/.aws`, `~/.netrc`, and denies the usual mutating commands (`git push`, `gh pr create`, `npm publish`, `sudo`, …).

## Permission Model

Verdicts are binary: **allow** (silent) or **deny** (error to user, no rewrite). There is no third "ask" state. Source attribution is implicit through the merged config chain — `fence config show` prints the inheritance chain to stderr and the effective JSON to stdout. No learning, no telemetry, no rule attribution at decision time. Decisions are pure functions of the resolved config plus the request (command string, domain, path).

In hook mode, the helper produces three outcomes via `hookShellDecision` (`cmd/fence/hooks_runtime.go:34-38`): `hookShellNoChange` (pass through unchanged), `hookShellDeny` (block at hook time), `hookShellWrap` (rewrite the agent's bash invocation to `fence -c "<original>"`).

## Hook / Integration Model

Per-agent adapter pattern with a shared evaluator. The fence binary multiplexes hook helpers via internal-mode flags:

- `cmd/fence/hooks_claude.go` — `--claude-pre-tool-use`, accepts Claude's `PreToolUse` JSON and returns `{"hookSpecificOutput":{"permissionDecision":"allow"|"deny","updatedInput":{...}}}`.
- `cmd/fence/hooks_cursor.go` — `--cursor-pre-tool-use`, accepts Cursor's `preToolUse` payload (also accepts Claude shape because Cursor may forward Claude hooks).
- `cmd/fence/hooks_opencode.go` — `--opencode-pre-tool-use`, flat `{"decision","reason","tool_input"}` response consumed by the npm package `@use-tusk/opencode-fence` (separate repo) which implements OpenCode's `tool.execute.before` plugin lifecycle.

All three adapters are thin JSON shape adapters that converge into one shared `evaluateShellHookRequest()` (`cmd/fence/hooks_runtime.go:81-104`). The shared core: parse args for `--settings`/`--template`, run `sandbox.CheckCommand` (preflight deny check), then either deny or rewrite `tool_input.command` to `<fence-exe> [pinned settings/template] -c <original-command>`. `FENCE_SANDBOX=1` is set inside the sandbox so nested hook invocations recognize they're already fenced and skip re-wrapping.

The CLI manages installation declaratively: `fence hooks {print,install,uninstall} --{claude,cursor,opencode} [--settings PATH | --template NAME] [--file PATH]`. Default targets are `~/.claude/settings.json`, `~/.cursor/hooks.json`, `~/.config/opencode/opencode.{jsonc,json}`. `hooks_jsonc_edit.go` does AST-aware JSONC edits (preserving comments where possible) and prompts before destructive rewrites. There is **no Codex adapter** despite docs listing Codex — Codex users wrap the whole agent (`fence -t code -- codex`) and rely on argv runtime exec or whole-process sandboxing.

## CLI / UX

Single binary (`cmd/fence/main.go:105-176`). Subcommands: root run, `import` (translate Claude settings → fence config), `config {show,init [--scaffold]}`, `hooks {print,install,uninstall}`, `completion`. Top-level flags: `-d/--debug`, `-m/--monitor`, `-s/--settings`, `-t/--template`, `-c <cmd>`, `-p/--port` (inbound expose, repeatable), `--expose-host-path[-rw]`, `--shell {default|user}`, `--shell-login`, `--fence-log-file`, `--list-templates`, `--linux-features`. Internal helper modes (not user-facing): `--landlock-apply`, `--linux-argv-exec-{run,shim}`, plus the three `--*-pre-tool-use` hook entry points.

Default behavior: deny-all network, allowlist by domain only. Use `--` to disambiguate fence flags from the wrapped command.

## Daemon Lifecycle

**None.** Fence is per-invocation. Each `fence -- <cmd>` starts proxies and bridges, runs the command, then `Manager.Cleanup()` tears them down (`internal/sandbox/manager.go`). Hook invocations are independent short-lived processes that re-load and re-resolve config every call.

## Failure Modes

There is no socket or PID to lose. Hook helper failure modes:

- Hook helper errors (config load, command parse, JSON decode) propagate as non-zero exit. Claude's hook contract treats non-zero as block.
- Inside an already-fenced session, the helper detects `FENCE_SANDBOX=1` and degrades to "policy check only, do not re-wrap" so the agent never doubles up sandboxes.
- For commands with subshells (`` ` `` or `$(…)`) or chained operators outside a pure `cd`, the helper conservatively wraps the whole string rather than parsing into pieces.
- Whole-agent wrapping (`fence -- claude`) bypasses hooks entirely; the docs explicitly warn that without hooks, multi-token denies on macOS only catch the literal command Fence was given, not descendant agent-spawned children (Seatbelt limitation).

## Notable Design Ideas

- **Shared evaluator + thin per-agent shape adapters.** Three hook entry points, one `evaluateShellHookRequest`, identical command-policy semantics across Claude/Cursor/OpenCode.
- **Hook = command rewrite, not just verdict.** Allowed commands are mutated to nest under `fence -c`, so agent-issued bash inherits the same policy without any extra plumbing — composes with whole-agent wrapping rather than replacing it.
- **`extends`/`@base` config inheritance with deterministic merge semantics** (slice append-dedupe, bool OR, scalar override). Project-local `fence.jsonc` discovered up the directory tree gives per-repo overrides.
- **Argv-aware runtime exec on Linux** (`runtimeExecPolicy: "argv"`) via seccomp user notification, so multi-token denies like `git push` reach descendant processes — the host-side fence supervisor inspects each `execve` argv. Path-mode is the default and just bind-masks denied executables.
- **Built-in templates as first-class onboarding** (`-t code`). The single `code.json` template is the documented integration path for Claude Code, Codex, Gemini CLI, etc.
- **Mandatory dangerous-path protection** is independent of user config (`internal/sandbox/dangerous.go`): writes to shell rc files, nested `.git/hooks/`, agent config dirs are always blocked.

## Anti-Patterns / Caveats

- **No Codex adapter** despite README claims. Codex relies on whole-process wrapping, which on macOS leaks multi-token command denies through child processes. Claim of "works with Codex" is template-only, not hook-level.
- **OpenCode `!`-prefixed TUI commands bypass the plugin lifecycle** entirely — multi-token denies are silently not enforced for that path.
- **Cursor needs the `code-relaxed` template** because Node.js/undici ignores `HTTP_PROXY` — the proxy-based network filter does not enforce on it. The `code` template silently doesn't work for that agent.
- **Linux requires `bubblewrap` + `socat` (and `bpftrace` for `-m`).** Hard dependencies on host packages; no fallback for environments without them.
- **JSONC comment preservation is best-effort** for `hooks install --opencode`; the CLI prompts before stripping comments. Same pattern is needed for any tool that writes user config files.

## Key File Pointers

- `cmd/fence/hooks_runtime.go:81-104` — shared `evaluateShellHookRequest`, the unified hook decision core.
- `cmd/fence/hooks_runtime.go:73-79` — `wrapShellCommand`, the rewrite-to-`fence -c` logic.
- `cmd/fence/hooks_claude.go:46-91` — Claude `PreToolUse` adapter.
- `cmd/fence/hooks_cursor.go` — Cursor adapter (also accepts Claude payloads).
- `cmd/fence/hooks_opencode.go:38-90` — OpenCode adapter, paired with external `@use-tusk/opencode-fence` npm plugin.
- `cmd/fence/hooks_cmd.go:13-303` — `fence hooks {print,install,uninstall}` cobra subcommands.
- `cmd/fence/main.go:105-176` — root cobra command, all top-level flags, subcommand registration.
- `internal/config/config.go:18-123` — `Config` struct and all category sub-structs (the canonical schema).
- `internal/config/config.go:127-166` — `DefaultDeniedCommands` built-in deny list.
- `internal/config/config.go:686-816` — `Merge`/`mergeStrings`/`mergeOptionalBool` inheritance semantics.
- `internal/templates/code.json` — canonical AI-agent template.
- `internal/sandbox/manager.go` — runtime orchestration, proxy/bridge lifecycle, cleanup.
- `internal/sandbox/command.go` — `CheckCommand` preflight, parses `&&`/`||`/`;`/pipes/`sh -c`.
- `internal/sandbox/runtime_exec_argv_linux.go` — seccomp-user-notif argv-aware exec supervisor.
- `internal/sandbox/dangerous.go` — mandatory dangerous-path protection.
- `internal/proxy/{http,socks}.go` — domain-filtering proxies.
- `pkg/fence/fence.go` — public Go API for embedding.
- `docs/agents.md` — agent integration matrix and hook usage.
- `ARCHITECTURE.md` — authoritative high-level design (mermaid diagrams, platform comparison).
