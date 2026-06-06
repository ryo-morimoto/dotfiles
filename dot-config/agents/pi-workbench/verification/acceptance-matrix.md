# Pi Workbench Acceptance Matrix

Date: 2026-05-29

| Acceptance criterion | Evidence file | State |
| --- | --- | --- |
| Zed can operate Pi through `acp-adapter`. | `candidate-evaluations/acp-adapter.md` | pending |
| Pi uses selected packages for MCP, context, telemetry, redaction, skills, and subagents. | `candidate-evaluations/my-pi.md` | pending |
| Permission rules block or ask for risky filesystem, git, network, and bash operations. | `candidate-evaluations/pi-permission-system.md` | pending |
| `codedb` provides codebase context without custom graph code. | `candidate-evaluations/codedb.md` | pending |
| `lsmcp` provides LSP-grounded diagnostics, symbols, and references. | `candidate-evaluations/lsmcp.md` | pending |
| Engram Pi package is configured and core `mem_*` tools are smoke-tested. | `candidate-evaluations/engram.md` | pending |
| Magic Context is configured or explicitly rejected/deferred because it conflicts with Engram. | `candidate-evaluations/magic-context.md` | pending |
| Codex, Claude, Gemini, and opencode sessions are searchable through `ai-sessions-mcp`. | `candidate-evaluations/ai-sessions-mcp.md` | pending |
| Pi session search has existing support, upstream adapter path, or tiny local importer with deletion path. | `candidate-evaluations/ai-sessions-mcp.md` | pending |
| Code Mode uses `pctx` or `mcpc`; no local sandbox exists. | `candidate-evaluations/pctx.md` | pending |
| Verification loop can run one code-intelligence check and one test/review tool. | `candidate-evaluations/codedb.md`, `candidate-evaluations/lsmcp.md` | pending |
| At least one local/open-weight model is configured for low-risk summarization. | `reuse-inventory.md` | pending |
| APM manifest or examples document reproducible setup. | `reuse-inventory.md` | pending |

## Completion Rule

MVP is not complete until every row is pass or explicitly deferred with a
written reason and replacement path. Pending rows must not justify local source
code.
