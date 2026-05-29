# pctx Evaluation

Candidate: `portofcontext/pctx`
Date checked: 2026-05-29
Source checked: GitHub HEAD `0b9312decb8673fbb9d8013e4a6495bb5cd7d703`

## Contract

- Code Mode can call configured MCP servers.
- Generated code runs in a sandbox without raw filesystem, environment, or network access except configured hosts.
- MCP auth secrets are not exposed to generated code.
- Long-running work can report status or be rejoined.
- `codedb`, `lsmcp`, and memory tools can be exposed through the aggregate.

## Install Command To Try

```sh
git clone https://github.com/portofcontext/pctx /tmp/pctx
```

Use the published npm package or the repository install path:

```sh
npx -y @portofcontext/pctx --help
```

## Minimal Config To Try

Register only read-only MCP servers first: `codedb`, `lsmcp`, and memory search. Add write-capable tools only after
permission gates are verified.

## Smoke Commands

```text
Run a Code Mode snippet that calls codedb_context through pctx.
Run a snippet that attempts filesystem/env access and confirm it is blocked.
```

## Observed Behavior

Candidate exists at the checked GitHub HEAD. npm package `@portofcontext/pctx@0.7.1` exists, and `npx -y
@portofcontext/pctx --help` passed. Help lists `start` and `mcp` commands.

Sandbox and upstream MCP execution were not exercised.

Receipt: `verification/receipts/2026-05-29-local-smoke.md`.

## Disposition

Adopt first for Code Mode. Use `mcpc` for scriptable MCP composition and JSON-output compatibility tests.

## Local Adapter Justified?

No.
