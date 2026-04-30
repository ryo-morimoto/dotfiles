# sandbox-broker permission engine — foundational design

This directory contains the formal design documents for **sandbox-broker**, a
local permission broker that mediates filesystem / network / command
operations issued by AI coding agents (Claude Code, Codex, future agents) on
the developer's host machine.

The current in-tree implementation grew opportunistically and has documented
UX problems (default policy denies everything, hooks fail-closed when broker
is unreachable, hook scripts duplicate jq/curl logic across agents). This
design is a **full rewrite informed by an 8-tool competitive study**
([refs/synthesis.md](./refs/synthesis.md)).

## Overview

sandbox-broker is a long-lived per-project daemon that an AI coding agent's
PreToolUse hook calls before each filesystem / network / command operation.
The broker returns `allow` / `deny` / `ask` based on a layered policy chain
and durable session state. The broker is what mediates between an agent's
free-running tool calls and the host machine; the agent gets fewer prompts,
the user retains an audit trail, and dangerous operations are stopped
without depending on a kernel sandbox being available.

The design optimises for five qualities:

1. **Usable defaults** — out of the box, common AI-agent operations should
   pass without prompts, and the typical secret/destructive operations
   should reliably stop. No "default policy denies everything" trap.
2. **Multi-agent unified** — Claude Code and Codex share one decision core
   behind thin per-agent shape adapters. New agents are added by writing a
   shape adapter, not a new policy engine.
3. **Declaratively deployed** — Nix Home Manager owns hook registration and
   default policy templates. The broker binary is the single produced
   artifact.
4. **Auditable** — every verdict is logged with rule provenance; an
   `explain` subcommand replays the decision chain for any operation.
5. **Fail-safe by default but degradeable** — security-critical paths
   fail-closed; hook subprocess errors fail-open so a bug in the broker does
   not brick the agent session.

## Design core

- **Asymmetric default by category** — read defaults to allow with
  deny-list of secrets; write and network default to deny with explicit
  allow-list. Mirrors `sandbox-runtime` and Fence.
- **Mandatory-deny bedrock** — a hard-coded list (`~/.bashrc`, `.git/hooks/**`,
  `.mcp.json`, `.claude/commands/**`, `.codex/**`, this design's own
  `policy.toml`) is denied for write **before any user policy applies**, so
  an agent can't rewrite its own permissions.
- **Seven-stage verdict chain** — `mandatory_deny → policy.commands →
  policy.filesystem → policy.network → session → programmatic → escalate`.
  Each stage emits a typed `Verdict` with `Source` provenance.
- **TOML policy with `extends`** — built-in templates (`@builtin/code`,
  `@builtin/code-strict`, `@builtin/git-readonly`) are first-class
  onboarding, and project policies inherit via `extends`. Merge semantics
  are deterministic (slice append-dedupe, scalar override).
- **Per-agent shape adapter, shared evaluator** — `sandbox-broker hook
  claude` and `sandbox-broker hook codex` are thin Rust subcommands that
  translate the agent's hook JSON into a shared internal `Operation` and
  return the agent's expected response shape. The current `.sh` adapters
  are removed.
- **Daemonize-by-default** — `sandbox-broker start` self-reexecs into a
  `--foreground` child, writes a PID file, and exits. `stop` reads the PID
  and sends SIGTERM; the daemon's signal handler runs the cleanup stack
  (socket / PID / log file).
- **Capability probe at boot** — `sandbox-broker doctor` and `start` probe
  for Landlock kernel ABI and bwrap availability and cache the result. A
  policy that requires a primitive that isn't available is rejected at
  start time, not at the first hit.
- **Hard-fail on invalid policy** — invalid TOML or schema mismatch errors
  out at parse time. Falling back to `Policy::default()` (the current
  behaviour) is explicitly removed.

![Layer positioning of broker against the L1 / L3 landscape](./diagrams/layer-positioning.svg)

## Document structure

Each chapter is a self-contained markdown file. We recommend reading them
in this order during implementation:

### Foundations

1. [Architecture](./architecture.md)
   - Problem statement (current broker UX failures, with concrete examples)
   - Goals (5 qualities)
   - Inspiration (Fence / Codex / sandbox-runtime / Landrun, with rejection
     rationale for full mimicry)
   - Layer positioning (L1 / L2 / L3)
   - Component map and data flow
   - Public surface (CLI subcommand catalogue, UDS protocol)
   - Key design decisions

2. [Verdict flow](./verdict-flow.md)
   - The seven-stage decision chain
   - `Verdict` struct (outcome / source / risk / rationale /
     amendment_proposal)
   - `Source` provenance enum
   - Worktree resolution rules
   - Mandatory-deny override attempts and how they're handled
   - Edge cases

### Policy

3. [Policy DSL](./policy.md)
   - Top-level TOML schema
   - `extends` inheritance and merge semantics
   - `mandatory_deny` shape (build-time bedrock + `user_extra` only)
   - `filesystem.{read,write}` asymmetric defaults
   - `network` allow-list with domain pattern hardening
   - `[[commands]]` prefix-rules with `examples` / `not_examples`
     parse-time validation
   - `[runtime]` knobs (daemonize / fail-open behaviour / wrap_allowed_bash)

4. [Matcher semantics](./matcher.md)
   - Prefix-rule matching (first-token index + alternatives + tokenwise
     prefix)
   - Path glob matching (allow vs deny precedence per category)
   - Domain pattern matching (exact / `*.example.com` / IP literal /
     canonicalisation)
   - Match-result composition

### Integration

5. [Hook subcommand adapters](./hooks.md)
   - The shared evaluator (Rust, replaces `.sh`)
   - `sandbox-broker hook claude` adapter
   - `sandbox-broker hook codex` adapter
   - JSON shape translation (Claude PreToolUse / Codex hook)
   - Failure modes (broker unreachable / broker timeout / decode error)
   - `permissionDecision` semantics (`allow` / `deny` / `ask`) and the
     `ask`-fail-open caveat for Codex

6. [Daemon lifecycle](./lifecycle.md)
   - `start` self-reexec into `--foreground` child
   - PID file, log file redirection, working-directory model
   - Cleanup-stack pattern (LIFO + priority slot)
   - Capability probe at boot
   - Signal handling (SIGTERM / SIGINT / SIGHUP for reload)
   - Hard-fail rules (invalid policy / missing primitive)

### Observability

7. [Audit and explain](./audit.md)
   - Verdict ring buffer (in-memory + file-backed)
   - `explain <op-json>` — replays the chain, shows which rule fired
   - `log [--since DUR]` — dumps recent verdicts
   - `policy show` — resolved policy after `extends` merge
   - Amendment proposal flow ("approve and remember" → policy diff)

### Templates and rollout

8. [Built-in templates](./templates.md)
   - `code` — default for AI agents (allow common dev domains, deny
     secrets, deny mutating commands)
   - `code-strict` — same shape with tighter network allow-list and
     stricter command policy
   - `git-readonly` — read-only git inspection (status / diff / log /
     show only)
   - Authoring guidance for new templates

9. [Implementation phases](./phases.md)
   - Phase 1: foundational rewrite (this design's full scope)
   - Phase 2: amendment proposal generation, audit ring buffer, two-tier
     policy (`~/.config/sandbox-broker/global.toml`), `extends` paths
   - Phase 3: egress proxy for domain-level network policy, `--ldd`-style
     ELF dependency walker, Codex `PermissionRequest` event
   - Migration strategy (Nix `home/agents/default.nix` rewire)

10. [Testing strategy](./testing.md)
    - Test categories (policy parse / matcher / evaluator chain /
      mandatory-deny / hook adapter shape / daemon lifecycle / capability
      probe / audit log)
    - Per-Phase staged adoption
    - Reuse of existing `tests/` corpus

## Related documents

- [`AGENTS.md`](../../../../AGENTS.md) — repository agent operations and
  declarative-management guard rails (`home/agents/default.nix` is the
  registered hook source).
- [`home/agents/default.nix`](../../../../home/agents/default.nix) — current
  declarative wiring of Claude Code and Codex hooks.
- [`tools/sandbox-broker/CLAUDE.md`](../../CLAUDE.md) (TBD) — agent-facing
  notes for working in this crate.

## References

The 8-tool competitive study and the cross-cutting synthesis live under
[`./refs/`](./refs/). These are **non-normative**: investigation history
and rejected alternatives, not specifications.

### Cross-cutting

- [`./refs/synthesis.md`](./refs/synthesis.md) — synthesis of all 8 reports;
  layer map, convergent patterns, anti-patterns, prioritised pick list.

### Per-tool deep dives

L1 (process-level kernel sandbox primitives):

- [`./refs/sandbox-runtime.md`](./refs/sandbox-runtime.md) — Anthropic's
  `srt` (per-invocation wrapper, asymmetric defaults, mandatory-deny list).
- [`./refs/fence.md`](./refs/fence.md) — Use-Tusk's Fence (per-agent thin
  adapter + shared evaluator, `extends` config, hook = command rewrite).
- [`./refs/landrun.md`](./refs/landrun.md) — Landlock CLI (path-class DSL,
  unprivileged enforcement primitives, `--ldd` ELF walker).

L2 (in-process policy / hook engine — same layer as broker):

- [`./refs/codex.md`](./refs/codex.md) — OpenAI Codex CLI (Starlark
  execpolicy, three-axis `SandboxPolicy` × `approval_policy` ×
  `prefix_rule`, amendment proposal).

L3 (workspace VM / container — different abstraction layer, transferable
patterns):

- [`./refs/e2b.md`](./refs/e2b.md) — E2B Firecracker microVM platform
  (cleanup-stack, two-tier nftables policy, MMDS bootstrap).
- [`./refs/daytona.md`](./refs/daytona.md) — Daytona container workspaces
  (desired-state reconciler, `DAYTONA-SB-` chain GC, per-sandbox auth
  token).
- [`./refs/agent-infra.md`](./refs/agent-infra.md) — All-in-one agent
  Docker image (single-port fan-out, MCP HTTP RPC introspection).
- [`./refs/windmill.md`](./refs/windmill.md) — NSJail per-job sandbox
  (capability probe at boot, `oom_score_adj=1000` bias trick,
  annotation-driven opt-in).

## Diagram regeneration

Diagrams are committed as both `.mmd` source and `.svg` rendering under
[`./diagrams/`](./diagrams/). Rendering uses
[`beautiful-mermaid`](https://www.npmjs.com/package/beautiful-mermaid) — a
synchronous, pure-TS Mermaid renderer with no Puppeteer / Chrome
dependency, so it works on NixOS without library-deps headaches. The
script and `package.json` live one level up so the same tooling renders
every design folder.

To regenerate after editing a `.mmd`:

```bash
cd tools/sandbox-broker/designs
npm install                                # one-time
node render-diagrams.mjs                   # render every design
node render-diagrams.mjs 001-permission-broker  # render only this design
```

The renderer uses the `github-light` theme by default; change it in
`render-diagrams.mjs` if needed. `beautiful-mermaid` supports flowchart,
state, sequence, class, ER, and XY chart diagrams. Other diagram types
(timeline etc.) need to be authored as one of the supported kinds.

This is a slight extension of the upstream design-doc convention used in
projects like [kazupon/ox-jsdoc](https://github.com/kazupon/ox-jsdoc/tree/main/design),
which commits SVGs only. Keeping `.mmd` source in-tree means anyone with
the renderer can rebuild without an external pipeline.
