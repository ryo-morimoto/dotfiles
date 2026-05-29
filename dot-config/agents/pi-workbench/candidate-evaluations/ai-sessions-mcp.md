# ai-sessions-mcp Evaluation

Candidate: `yoavf/ai-sessions-mcp`
Date checked: 2026-05-29
Source checked: GitHub HEAD `3bc31862280d7ac1d5097626c4c3bfb4b990fd20`

## Contract

- Search Codex sessions by keyword.
- Search Claude, Gemini CLI, and opencode sessions where present.
- List recent sessions by project.
- Retrieve paginated session content.
- Add Pi session search through existing paths, upstream adapter, or a tiny local importer.
- Avoid indexing secrets in snippets.

## Install Command To Try

```sh
git clone https://github.com/yoavf/ai-sessions-mcp /tmp/ai-sessions-mcp
```

Use the repository-documented MCP server install command. The public npm name `ai-sessions-mcp` was not available when
checked.

## Minimal Config To Try

Point the server at disposable copies of local Codex and Claude session directories first. Do not index live secrets or
private credentials during evaluation.

## Smoke Commands

```text
search_sessions("pi workbench")
list_recent_sessions(project="dotfiles")
get_session(session_id="REPLACE", page=1)
```

## Observed Behavior

Source smoke passed: `go test ./...`, `go build ./cmd/ai-sessions`, and CLI help all succeeded from a shallow clone.
README lists Claude Code, Gemini CLI, OpenAI Codex, and opencode. Source adapters include Claude, Codex, Copilot,
Cursor, Gemini, Mistral, and opencode. No Pi adapter was present.

Receipt: `verification/receipts/2026-05-29-local-smoke.md`.

## Disposition

Adopt for supported agent histories. Decide upstream Pi source adapter versus local importer only after inspecting Pi
session files.

## Local Adapter Justified?

Not yet for local repo code. The Pi session source gap is confirmed; preferred next step is an upstream adapter unless
the Pi session format requires a temporary importer.
