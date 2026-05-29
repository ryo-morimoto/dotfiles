# Decisions

Date: 2026-05-29

## Adopt

| Area | Decision | Reason |
| --- | --- | --- |
| ACP | Use `beyond5959/acp-adapter`. | It already targets Pi RPC through ACP, so a local ACP server is unnecessary. |
| Runtime packages | Use selected `spences10/my-pi` packages. | The packages cover MCP, LSP, context, recall, telemetry, redaction, skills, and team mode with Node `>=24.15.0`. |
| Permissions | Use Pi gates plus `MasuRii/pi-permission-system`. | Policy enforcement belongs in runtime/tool settings, not a prompt or local DSL. |
| Durable memory | Start with Engram. | It has a Pi setup path and both lifecycle capture and agent-visible MCP tools. |
| Context compaction | Evaluate Magic Context separately. | It overlaps with memory writers, so duplicate writes must be tested before enabling together. |
| Session search | Use `ai-sessions-mcp` for non-Pi histories. | It already covers Codex/Claude/Gemini/opencode; Pi is the known missing source. |
| Code Mode | Use `pctx` first and `mcpc` for shell/JSON checks. | Code execution should stay in an existing sandbox/composition layer. |
| Code intelligence | Use `codedb` and `lsmcp` directly. | MVP needs textual/query surfaces, not a custom graph engine. |
| Distribution | Use APM examples and manifests. | Package lifecycle should be delegated to the existing package manager. |
| Local models | Use Pi custom model config and OpenAI-compatible endpoints. | Routing can stay manual/config-driven for MVP. |

## Reject For MVP

- Custom ACP server.
- Custom agent framework.
- Custom package manager.
- Custom permission language or Cedar policy layer.
- Custom memory database, vector store, dreamer, or graph memory.
- Custom Code Mode runtime or Deno sandbox.
- Custom graph viewer.
- Custom provider router.
- Custom subagent orchestrator.

## Deferred

| Topic | Deferred until |
| --- | --- |
| Pi source in `ai-sessions-mcp` | Existing session path is inspected and upstream contribution cost is known. |
| Engram + Magic Context together | Duplicate write, prompt injection, and hook ordering behavior are tested. |
| `@spences10/pi-team-mode` | Minimal `pi-subagent` and permission-forwarding behavior are checked first. |
| `vibe-lang` | MVP tool composition proves an action DSL is needed. |
| MoonBit kernels | Stable data model exists for scoring, receipts, or capability checks. |

## Local Code Gate

Do not create `tools/pi-workbench-adapters/` unless a candidate evaluation records a failed contract and names the exact
adapter surface. Allowed surfaces are Pi session importer, config translator, receipt/log importer, or compatibility
test repros.

