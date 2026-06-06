# Candidate Evaluation: my-pi

Source: `https://github.com/spences10/my-pi`
Current ref: `e79ef66eecbd8e222ab4e792d2acf7193539e597`
Role: Pi-native package set for MCP, LSP, context, recall, telemetry,
redaction, skills, and team mode.

## Install

Tried: not yet.

Commands to try in disposable Pi config:

```sh
pi install npm:@spences10/pi-mcp
pi install npm:@spences10/pi-lsp
pi install npm:@spences10/pi-context
pi install npm:@spences10/pi-recall
pi install npm:@spences10/pi-telemetry
pi install npm:@spences10/pi-redact
pi install npm:@spences10/pi-skills
```

Node prerequisite to verify: `>=24.15.0`.

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| Package install works with current Pi. | pending | Use disposable config first. |
| Project and global config are understandable and reproducible. | pending | Capture exact generated files. |
| MCP config can be project scoped. | pending | Required for repo-specific tools. |
| Telemetry/context data is local and inspectable. | pending | Record storage paths. |
| Redaction happens before logs, memory, or session export. | pending | Test with fake secret strings only. |

## Decision

Prefer selected packages. Do not install the whole package set blindly and do
not create local Pi packages before a specific package fails a contract.
