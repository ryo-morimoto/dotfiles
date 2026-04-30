# Landrun

Source: https://github.com/Zouuup/landrun (commit fetched 2026-04-29, version 0.1.15)

## Summary

Per-process Landlock sandbox CLI written in Go (`landrun [flags] <cmd> ...`). It is a primitive enforcement layer, not a broker: there is no daemon, no IPC, no policy file, and no allow/deny prompts. We study it for its DSL ergonomics (read/write/exec path classes, TCP port lists) and for the unprivileged kernel-mediated enforcement model that any broker on Linux should sit on top of.

## Architecture

Single-process wrapper. Flow (`cmd/landrun/main.go:91`):

1. Parse CLI flags via `urfave/cli/v2` into a `sandbox.Config` struct.
2. Optionally compute extra read-only-exec paths via ELF dependency walking (`internal/elfdeps/elfdeps.go:175`) — parses `PT_INTERP`, `DT_NEEDED`, `DT_RPATH`/`DT_RUNPATH`, expands `$ORIGIN`, falls back to `ldconfig -p`.
3. Call `sandbox.Apply(cfg)` (`internal/sandbox/sandbox.go:103`) which builds `landlock.Rule` lists and invokes `landlock.V5.RestrictPaths(...)` and `RestrictPaths(...).RestrictNet(...)` from `github.com/landlock-lsm/go-landlock`. Those wrap the `landlock_create_ruleset(2)`, `landlock_add_rule(2)`, and `landlock_restrict_self(2)` syscalls plus a `prctl(PR_SET_NO_NEW_PRIVS, 1)`.
4. `syscall.Exec` (`internal/exec/runner.go:20`) replaces the landrun process image with the target. The Landlock ruleset is inherited by the exec'd process and all of its children — no supervisor stays around.

There is no namespace, no seccomp, no cgroup, no chroot. Enforcement is entirely Landlock LSM rules attached to the task struct.

## Policy / Config DSL

CLI flags only — no config file, no JSON/YAML. Path-class DSL with four orthogonal modes plus two TCP modes:

| Flag | Semantics |
|---|---|
| `--ro PATH` | read files + read dir |
| `--rox PATH` | read + execute (libs, binaries) |
| `--rw PATH` | read + write + truncate + ioctl + dir mutation (`make_*`, `remove_*`, `refer`) |
| `--rwx PATH` | rw + execute |
| `--bind-tcp PORT` | allow `bind(2)` on listed TCP ports |
| `--connect-tcp PORT` | allow `connect(2)` on listed TCP ports |
| `--env KEY` / `--env KEY=VAL` | explicit env passthrough; default is empty env |
| `--unrestricted-filesystem` / `--unrestricted-network` | escape hatches per axis |
| `--best-effort` | degrade to highest ABI the kernel supports |
| `--add-exec` / `--ldd` | auto-derive `--rox` for the target binary and its shared libs |

Each path flag is repeatable or comma-separated. Path classes are unioned: `--ro` and `--rox` both contribute to read-only; `--rox` and `--rwx` both contribute to executable (`cmd/landrun/main.go:97-107`). Granularity is per-path-class; you cannot, for example, allow `read_file` but deny `read_dir` on the same path. Permission expansion is computed in `getReadOnly*Rights` / `getReadWrite*Rights` (`internal/sandbox/sandbox.go:25-92`) which maps each class to a fixed `landlock.AccessFSSet` bitmask.

No deny rules — Landlock itself is allow-list only. No glob/regex; paths are passed verbatim as anchors and Landlock applies them to subtrees.

## CLI / UX

No subcommands; everything is one `landrun` invocation. Composes naturally as a prefix wrapper (e.g. inside systemd `ExecStart=`, inside `bash -c`, inside CI). Defaults are aggressive: empty env, no FS access, no net access — `landrun ls` produces "maximum security jail" that immediately fails. `--log-level debug` plus `strace` is the documented debugging path. Versioned (`Version = "0.1.15"`).

## Failure Modes

- Kernel below 5.13 / Landlock disabled: `RestrictPaths` returns an error and landrun aborts unless `--best-effort` is set, in which case enforcement silently downgrades (no net restrictions on <6.7, no truncation control on <6.2, no enforcement at all on <5.13). README documents the matrix at lines 300–308.
- Empty rule set without `--unrestricted-*`: applies `llCfg.Restrict()` which denies everything Landlock can deny (`internal/sandbox/sandbox.go:165`).
- Already-open FDs are not restricted (Landlock semantics — README line 298). A broker process must open its rule set after, not before, any FD it intends to keep usable.
- Files referenced by path before sandboxing (e.g., shared libraries the dynamic loader will demand) must be in `--rox` or the process can't even start; hence `--ldd`.

## Notable Design Ideas

- **Path-class DSL collapsing 12+ Landlock access bits into 4 modes** (`ro`/`rox`/`rw`/`rwx`) is a usable abstraction worth borrowing for the broker's policy surface. Users almost never want to tune individual `LANDLOCK_ACCESS_FS_*` bits.
- **Unprivileged enforcement via Landlock + `NO_NEW_PRIVS`** — no setuid, no daemon, no capabilities. The broker can apply this exact pattern as its innermost confinement layer for spawned subprocesses without needing a privileged helper.
- **`syscall.Exec` instead of fork+wait** — landrun does not stay resident, so there's no IPC or supervisor cost. For a broker, the symmetric move is to exec into the agent after applying restrictions; intermediation must happen via a separate channel (e.g., a pre-opened socket the agent talks to) since once Landlock is on, you can't change it.
- **`--ldd` auto-derives executable allow-list** by walking ELF `DT_NEEDED` + `PT_INTERP` + `RPATH/RUNPATH` with `$ORIGIN` expansion (`internal/elfdeps/elfdeps.go:55-172`). Useful pattern for a broker that wants to whitelist agent-tool binaries automatically rather than asking the user to enumerate `/usr/lib`.
- **Per-axis escape hatches** (`--unrestricted-filesystem`, `--unrestricted-network`) are clearer than a single "disable" flag — preserves the structure of the policy while letting users carve out one dimension. Worth mirroring in the broker DSL.

## Anti-Patterns / Caveats

- **No deny / no glob / no precedence rules.** Allow-list-only is fine for a primitive, but a broker with policy authoring needs richer composition (deny override, project-relative globs, per-tool overrides) — landrun explicitly punts.
- **TCP-only network model.** `bind`/`connect` ports only; no UDP, no host/CIDR filtering, no DNS. This is a Landlock ABI v4 limit, not a landrun choice, but it means a broker cannot rely on Landlock alone for network policy and must layer (nftables, user-space proxy) on top.
- **Open FDs bypass enforcement.** Easy footgun if the broker pre-opens log files, sockets, or working directories before applying rules. Order of operations is load-bearing and must be encoded in the broker's startup sequence.

## Key File Pointers

- `cmd/landrun/main.go:18-176` — CLI shape, flag set, mode unioning, env passthrough.
- `internal/sandbox/sandbox.go:25-92` — path class to `AccessFSSet` mapping (the DSL semantics).
- `internal/sandbox/sandbox.go:103-192` — apply pipeline, default-deny branch, `--best-effort` and `--unrestricted-*` handling.
- `internal/exec/runner.go:10-21` — `syscall.Exec` post-restrict handoff.
- `internal/elfdeps/elfdeps.go:55-230` — ELF dependency walker for `--ldd`.
- `README.md:300-308` — kernel/ABI compatibility matrix.
