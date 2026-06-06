# Pi Agent Workbench

This directory tracks reuse-first evaluation for a Pi-based agent workbench.
It stores reviewed notes, candidate contracts, and config examples only.

It must not become a local agent framework. Local source code is allowed only
after a candidate fails a written contract and the missing behavior is small
enough to justify a thin adapter or reproducible upstream bug proof.

## Scope

MVP scope:

- Use `beyond5959/acp-adapter` for Zed ACP to Pi.
- Use selected existing Pi packages for MCP, LSP, context, recall,
  telemetry, redaction, skills, and subagents.
- Use `MasuRii/pi-permission-system` for scoped capabilities.
- Use `codedb` and `lsmcp` for codebase context.
- Use Engram first for durable memory, then compare Magic Context for
  compaction and auto recall.
- Use `ai-sessions-mcp` for existing Codex, Claude, Gemini, and opencode
  histories, with Pi session search treated as the known gap.
- Use `pctx` first for Code Mode.

Out of scope for MVP:

- custom ACP server
- custom permission language
- custom memory database
- custom Code Mode runtime
- custom graph viewer
- custom provider router
- custom subagent orchestrator
- custom package manager

## Files

- `reuse-inventory.md`: candidate map and current evaluation state.
- `decisions.md`: accepted, rejected, and deferred architecture decisions.
- `candidate-evaluations/`: one contract sheet per candidate.
- `verification/acceptance-matrix.md`: MVP acceptance checklist.

## Evaluation Rule

Each candidate must be evaluated in this order:

1. Record current version, commit, or release.
2. Record the exact install command to try.
3. Record the smallest config needed for a smoke test.
4. Run the smoke test in disposable config where possible.
5. Mark each contract pass, fail, blocked, or pending.
6. Prefer upstream issue or PR paths before local adapters.
