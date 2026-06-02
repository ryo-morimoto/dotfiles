# mcpc Evaluation

Candidate: `@apify/mcpc`
Date checked: 2026-05-29
Registry check: npm `0.3.0`, Node `>=20.0.0`

## Contract

- MCP servers can be composed from shell.
- JSON output is stable enough for smoke tests.
- Persistent sessions and OAuth flows work where needed.
- It complements `pctx` without becoming the primary Code Mode runtime.

## Install Command To Try

```sh
npx @apify/mcpc --help
```

## Minimal Config To Try

Register one read-only MCP server and call one tool with JSON output enabled.

## Smoke Command

```sh
npx @apify/mcpc --help
```

Then run the repository-documented command for calling a configured server tool.

## Observed Behavior

npm metadata is available. `npx @apify/mcpc --help` passed and listed `connect`, `tools-list`, `tools-call`,
`tasks-*`, and `--json`. `npx @apify/mcpc --json` returned empty `sessions` and `profiles`, which is expected without
active sessions.

Live MCP tool calls were not run because no server session was configured.

Evidence: current live check output from `pi list`, package help, build output, or candidate notes.

## Disposition

Use for compatibility tests and shell automation. Keep `pctx` as the first Code Mode candidate.

## Local Adapter Justified?

No.
