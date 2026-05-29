# Acceptance Matrix

Date: 2026-05-29

| Area | Acceptance criterion | Candidate | Status | Evidence path |
| --- | --- | --- | --- | --- |
| ACP | Zed can start a Pi-backed session and stream a response. | `acp-adapter` | Blocked on interactive Zed + authenticated Pi run; build/help partially verified | `verification/receipts/2026-05-29-local-smoke.md` |
| ACP sessions | Pi session new/list/load works through ACP bridge. | `acp-adapter` | Blocked on live Pi ACP run | `candidate-evaluations/acp-adapter.md` |
| Runtime packages | Selected Pi packages install in a disposable profile. | `spences10/my-pi` | Passed install/list smoke | `verification/receipts/2026-05-29-local-smoke.md` |
| Permissions | Safe commands allow, risky commands ask, denied commands block. | `pi-permission-system` | Install/list passed; blocked on live Pi runtime policy execution | `candidate-evaluations/pi-permission-system.md` |
| Permissions | MCP tool restrictions work by server/tool. | `pi-permission-system` | Blocked on live Pi runtime policy execution | `config.examples/pi/permissions.example.json` |
| Code context | Dependency neighborhood is available for changed files. | `codedb` | Passed CLI tree/search/outline; MCP tool surface not exercised | `verification/receipts/2026-05-29-local-smoke.md` |
| LSP context | Overview, symbols, diagnostics, and references work. | `lsmcp` | Package/help verified; project LSP tool calls not exercised | `verification/receipts/2026-05-29-local-smoke.md` |
| Memory | Engram exposes project, context, prompt, passive capture, and session lifecycle tools. | Engram | Build/test/help verified; MCP `mem_*` calls blocked on live Pi/MCP client | `verification/receipts/2026-05-29-local-smoke.md` |
| Memory conflict | Magic Context does not duplicate Engram writes or conflicting hints. | Magic Context + Engram | Blocked on isolated live Pi memory run | `config.examples/magic-context/split-responsibility.md` |
| Session search | Codex and Claude sessions are searchable by keyword and project. | `ai-sessions-mcp` | Build/test/help verified; live session search not exercised | `verification/receipts/2026-05-29-local-smoke.md` |
| Pi session search | Pi sessions are searchable through existing support, upstream adapter, or tiny importer. | `ai-sessions-mcp` | Confirmed gap: no Pi adapter in source tree | `candidate-evaluations/ai-sessions-mcp.md` |
| Code Mode | Code Mode can call MCP tools without raw filesystem/env/network access. | `pctx` | Package/help verified; sandbox execution blocked on configured upstream MCPs | `verification/receipts/2026-05-29-local-smoke.md` |
| MCP composition | A configured MCP tool can be called from shell with JSON output. | `mcpc` | CLI/help/JSON baseline passed; tool call blocked on configured server session | `verification/receipts/2026-05-29-local-smoke.md` |
| Subagents | Explorer/reviewer subagents run and permission prompts forward. | `pi-subagent` | Disposable install/list passed; spawn/fork blocked on authenticated live Pi run | `verification/receipts/2026-05-29-local-smoke.md` |
| Distribution | Manifest install/audit works without unrelated live config mutation. | APM | CLI/audit/dry-run passed; full install not run because example commands contain placeholders | `candidate-evaluations/apm.md` |
| Local models | Small model summarizes memory/session content; review model performs read-only review. | Pi custom models | Blocked: no local/open model endpoint configured | `candidate-evaluations/local-models.md` |

## Completion Rule

MVP is complete only when each `Pending live smoke` row has a dated receipt or an explicit rejected/deferred decision with
reason and replacement.
