# sandbox-runtime

## Summary

Anthropic's `srt` is a TypeScript/Node CLI + library that wraps a single child command in an OS-level sandbox (macOS `sandbox-exec` / Linux `bubblewrap`) plus in-process HTTP/SOCKS5 proxies for network filtering. It is not a long-lived broker — it is a per-invocation **command wrapper** with optional dynamic config reload over a file descriptor.

## Architecture

Three layers, all running inside the same `srt` process tree:

1. **Wrapper / orchestrator** — `src/cli.ts` (commander-based CLI) and `src/sandbox/sandbox-manager.ts` (singleton module-state "manager"). Manager `initialize()` boots proxies, resolves dependencies, then `wrapWithSandbox(cmd)` returns a fully-quoted shell string the CLI spawns.
2. **OS sandbox emitters** — platform-specific profile/argv generators:
   - `src/sandbox/macos-sandbox-utils.ts` builds a Seatbelt SBPL profile string and spawns `sandbox-exec -p <profile> <shell> -c <cmd>`.
   - `src/sandbox/linux-sandbox-utils.ts` builds a `bwrap` argv with `--ro-bind`, `--bind`, `--tmpfs`, `--unshare-net`, etc., plus a nested `apply-seccomp` for Unix-socket blocking.
3. **In-process network proxies** — `src/sandbox/http-proxy.ts` (HTTP CONNECT + plain HTTP) and `src/sandbox/socks-proxy.ts`. Both call into `sandbox-manager.filterNetworkRequest(host, port)` which checks denied → allowed → optional `SandboxAskCallback`. On Linux, proxies are reached via Unix sockets bridged into the bwrap namespace by `socat` (`linuxBridge` context).

Supporting modules: `parent-proxy.ts` (host canonicalization, upstream-proxy chaining, NO_PROXY), `sandbox-violation-store.ts` (in-memory ring buffer + listeners), `generate-seccomp-filter.ts` (BPF for `socket(AF_UNIX)`/`io_uring_*`).

## Policy / Config DSL

JSON file at `~/.srt-settings.json` (override `--settings`). Validated by Zod (`src/sandbox/sandbox-config.ts`). Top-level keys: `network`, `filesystem`, `ignoreViolations`, `mandatoryDenySearchDepth`, `enableWeakerNestedSandbox`, `enableWeakerNetworkIsolation`, `allowPty`, `seccomp`, `ripgrep`.

```json
{
  "network": {
    "allowedDomains": ["github.com", "*.npmjs.org"],
    "deniedDomains": ["malicious.com"],
    "allowUnixSockets": ["/var/run/docker.sock"],
    "allowLocalBinding": false,
    "httpProxyPort": 8080,
    "mitmProxy": { "socketPath": "...", "domains": ["api.x"] },
    "parentProxy": { "http": "...", "https": "...", "noProxy": "..." }
  },
  "filesystem": {
    "denyRead": ["~/.ssh"], "allowRead": ["."],
    "allowWrite": [".", "/tmp"], "denyWrite": [".env"],
    "allowGitConfig": false
  },
  "ignoreViolations": { "*": ["/usr/bin"], "git push": ["/usr/bin/nc"] }
}
```

Categories: filesystem read, filesystem write, network domain, Unix sockets, Mach lookups (macOS), local-port binding, PTY. **No** policy axis for command/exec or env. Domain pattern schema rejects bare `*`, `*.com`, paths/ports, schemes.

## Permission Model

Binary verdict: **allow** or **deny** (block via OS), with an optional **escalate-to-callback** branch when no rule matches (`SandboxAskCallback({host, port}) => Promise<boolean>`). The callback is library-only — the CLI defaults to deny on no-match.

Asymmetric defaults by category (see `sandbox-schemas.ts:1-55`):

- Read: deny-then-allow (default allow-all). `allowRead` overrides `denyRead`.
- Write: allow-only (default deny-all). `denyWrite` overrides `allowWrite`.
- Network: allow-only (empty allowlist = block all).

Source attribution is implicit — verdicts come from policy match, fallback callback, or hardcoded "mandatory deny" lists (`DANGEROUS_FILES`, `getDangerousDirectories()` in `sandbox-utils.ts:11-40`: `.bashrc`, `.zshrc`, `.gitconfig`, `.mcp.json`, `.git/hooks/`, `.claude/commands/`, etc.). No learning/persistence — every session reloads JSON.

## Hook / Integration Model

Two integration paths, **no daemon socket / IPC protocol**:

1. **Process-wrap (primary)**: agents spawn `srt <cmd>` (e.g. an MCP server config replaces `command: "npx"` with `command: "srt", args: ["npx", ...]`). Restrictions are pushed into the kernel; violations surface as `EPERM` to the child.
2. **Library**: `import { SandboxManager } from '@anthropic-ai/sandbox-runtime'`. Caller passes a `SandboxRuntimeConfig` and optional `SandboxAskCallback` to `initialize()`, then `wrapWithSandbox(cmd)` for each command. Same singleton state, same proxies.

Dynamic policy reload: `--control-fd <N>` reads JSON-lines from an inherited fd; each line is a full `SandboxRuntimeConfig` parsed by `loadConfigFromString` and applied via `updateConfig` (`cli.ts:99-135`). This is the only "request/response"-shaped protocol; there is no per-decision RPC — decisions stay in-process.

## CLI / UX

`srt [-d|--debug] [-s|--settings <path>] [-c <cmd>] [--control-fd <fd>] [command...]`. `-c` mirrors `sh -c`. No subcommands. No init flow — missing config = empty default config (most restrictive).

## Daemon Lifecycle

There is no daemon. Lifecycle is per-`srt` invocation:

- `initialize()` boots proxies on `127.0.0.1:0` (random ports), starts macOS `log stream` monitor if requested, and `unref()`s servers so they don't keep the loop alive.
- Cleanup is via `process.once('exit'|'SIGINT'|'SIGTERM', reset)` — kills socat bridges with SIGTERM (5s timeout, then SIGKILL), removes Linux bwrap mountpoint artifacts (empty files used as `--ro-bind` targets), stops the macOS log monitor.
- Config "reload" only via `--control-fd`. State is module-level globals in `sandbox-manager.ts`; `initializationPromise` deduplicates concurrent inits.

## Failure Modes

**Fail-closed by design.** Specific patterns:

- Missing config → empty default → effectively "no network, only `getDefaultWritePaths()` writable".
- Invalid Zod schema → `console.error` and `null` → falls back to default. (Soft failure; arguably should hard-error.)
- `filterNetworkRequest` denies on missing config, malformed host (control chars), or callback exception.
- Missing dependencies (`bwrap`, `rg`, `socat`, `apply-seccomp`) → `Error` thrown from `initialize`, no sandbox runs.
- WSL1 / unsupported platform → `isSupportedPlatform()` returns false; `wrapWithSandbox` throws.
- Proxy bind failure during init → `reset()` then re-throw, allowing retry.
- bwrap creates host-side empty files for non-existent deny mountpoints; cleaned post-command (`cleanupBwrapMountPoints`).

## Notable Design Ideas

- **Asymmetric default by category** (read=deny-then-allow, write/net=allow-only). Encodes intent: "everyone can read public stuff but writes/net need explicit grants" — much more usable than uniform deny-all.
- **Mandatory deny list independent of policy** (`DANGEROUS_FILES`, `.git/hooks`, `.claude/commands`). Defense-in-depth against the agent rewriting its own config or shell rc.
- **Domain pattern hardening** — Zod rejects `*`/`*.com`, `matchesDomainPattern` refuses IP literals as wildcard targets, host canonicalization (`canonicalizeHost`) defeats `inet_aton` shorthand bypass like `2852039166`.
- **Two-stage Linux isolation** (bwrap → nested userns + seccomp via `apply-seccomp`). Lets infrastructure (socat) keep `AF_UNIX` while user code can't, and the nested PID namespace prevents ptrace escapes regardless of `yama.ptrace_scope`.
- **`--control-fd` JSON-lines hot reload** — no socket, no auth, just a child fd. Trivial way for a parent agent to escalate or revoke permissions mid-session.
- **Log-store violation tap on macOS** — predicate filter on `eventMessage ENDSWITH "${sessionSuffix}"` plus base64-encoded command tags for correlation (`generateLogTag`). Effectively free violation telemetry without strace overhead.

## Anti-Patterns / Caveats

- **Module-level singleton state** in `sandbox-manager.ts` (`let config`, `let httpProxyServer`...). Library users can't run two configs in one process; tests must reset.
- **No structured decision log** — only macOS gets violations (via log stream); Linux users are told to "run strace yourself". An out-of-process broker would centralize this.
- **Invalid config silently degrades to default-empty** rather than refusing to start. Easy to ship a typo and end up with a more-permissive-than-intended sandbox.
- **No verdict provenance / audit trail** in the runtime API — `SandboxAskCallback` returns a bare boolean; no rule-id, no reason field. Hard to plug into a UI that wants "denied because policy:foo".
- **Linux glob support is missing** — silently filtered out. A `denyRead: ["**/.env"]` will not match anything; depends on `mandatoryDenySearchDepth` ripgrep scan as fallback. Confusing parity gap.

## Key File Pointers

- `src/cli.ts:38-218` — CLI entry, `--control-fd` JSON-lines reload loop.
- `src/sandbox/sandbox-config.ts:12-298` — Zod schema, domain-pattern validator, full config surface.
- `src/sandbox/sandbox-manager.ts:55-355` — module-state, `initialize`, `filterNetworkRequest`, `updateConfig`.
- `src/sandbox/sandbox-manager.ts:573-720` — `wrapWithSandbox` dispatch and per-platform argument shaping.
- `src/sandbox/sandbox-schemas.ts:1-65` — internal restriction config semantics, `SandboxAskCallback` signature.
- `src/sandbox/sandbox-utils.ts:11-40` — `DANGEROUS_FILES` / `getDangerousDirectories` mandatory-deny list.
- `src/sandbox/macos-sandbox-utils.ts:721-815` — Seatbelt profile assembly + `env ... sandbox-exec -p ...` wrapping.
- `src/sandbox/macos-sandbox-utils.ts:821-934` — `log stream` violation monitor with `ignoreViolations` filtering.
- `src/sandbox/linux-sandbox-utils.ts:973-1000` — comment block explaining two-stage bwrap + apply-seccomp design.
- `src/sandbox/http-proxy.ts:43-150` — CONNECT handling, MITM/parent-proxy routing, 403 response shape.
- `src/sandbox/sandbox-violation-store.ts:1-65` — in-memory ring buffer + subscribe API (model for our broker's audit log).
- `src/utils/config-loader.ts:11-68` — JSON+Zod load with soft-fail-to-default.
