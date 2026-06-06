# Candidate Evaluation: codedb

Source: `https://github.com/justrach/codedb`
Current ref: `e89e110a695ec64de2d3083b31644011457e55eb`
Role: MCP-native code intelligence and dependency context.

## Install

Tried: not yet.

Commands to try:

```sh
curl -fsSL https://codedb.codegraff.com/install.sh | bash
npx -y codedeebee mcp
```

## Smoke

Run against a real TypeScript repo and this dotfiles repo where applicable.

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| `codedb_context` answers task-shaped queries. | pending | Query a known code area. |
| `codedb_deps` gives dependency neighborhoods. | pending | Use a changed file as input. |
| Sensitive-file blocking is enabled and verified. | pending | Use fake sensitive file names only. |
| Snapshots can be created and compared. | pending | Useful for review loop. |
| Output is good enough for textual review surfaces. | pending | No graph viewer in MVP. |

## Decision

Adopt as first codebase context candidate. Do not build a local graph engine.
