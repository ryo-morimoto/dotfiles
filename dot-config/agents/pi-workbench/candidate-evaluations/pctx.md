# Candidate Evaluation: pctx

Source: `https://github.com/portofcontext/pctx`
Current ref: `0b9312decb8673fbb9d8013e4a6495bb5cd7d703`
Role: Code Mode over configured MCP servers.

## Install

Tried: not yet.

Commands to try:

```sh
npm i -g @portofcontext/pctx
pctx mcp init
pctx mcp dev
```

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| Can aggregate codedb and lsmcp MCP servers. | pending | Start with read-only tools. |
| Generated code can call configured MCP capabilities. | pending | Use a simple query task. |
| Sandbox cannot access raw filesystem/env/network. | pending | Test with harmless denied reads. |
| MCP auth secrets are not visible to generated code. | pending | Do not use real secrets in smoke. |
| Long-running tasks can report status or rejoin. | pending | Only if upstream supports it. |

## Decision

Use first for Code Mode. Do not build `code.execute` or a local Deno sandbox.
