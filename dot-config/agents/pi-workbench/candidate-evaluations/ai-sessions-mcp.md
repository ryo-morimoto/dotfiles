# Candidate Evaluation: ai-sessions-mcp

Source: `https://github.com/yoavf/ai-sessions-mcp`
Current ref: `3bc31862280d7ac1d5097626c4c3bfb4b990fd20`
Role: search and retrieval for local agent session histories.

## Install

Tried: not yet.

Commands to try:

```sh
curl -fsSL https://aisessions.dev/install.sh | bash
claude mcp add ai-sessions ~/.aisessions/bin/aisessions
```

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| Search Codex sessions by keyword. | pending | Use local non-secret query. |
| Search Claude sessions by keyword. | pending | Use local non-secret query. |
| List recent sessions by project. | pending | Verify project path grouping. |
| Retrieve paginated session content. | pending | Avoid dumping secret-bearing text. |
| Pi session files are supported or gap is proven. | pending | Known likely gap. |
| Exported snippets are redacted. | pending | Coordinate with redaction layer. |

## Decision

Use for existing agent histories. If Pi sessions are unsupported, prefer an
upstream source adapter; use a local importer only if upstream is blocked.
