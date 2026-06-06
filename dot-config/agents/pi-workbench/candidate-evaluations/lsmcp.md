# Candidate Evaluation: lsmcp

Source: `https://github.com/mizchi/lsmcp`
Current ref: `f2fb91d205c19ffff3be1d6f98bdc130b6e8868f`
Role: LSP-backed MCP for diagnostics, symbols, definitions, references, and
rename.

## Install

Tried: not yet.

Command to try:

```sh
npm install -g @mizchi/lsmcp
```

Node prerequisite to verify: `>=22`.

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| `get_project_overview` works in a TypeScript repo. | pending | Use a real TS repo. |
| `search_symbols` and `get_symbol_details` return useful results. | pending | Include one exported symbol and one local symbol. |
| Diagnostics are trustworthy enough for edit planning. | pending | Compare with project native diagnostics. |
| References and rename work where language server supports them. | pending | Avoid applying rename in smoke. |
| MoonBit preset works in a MoonBit repo. | pending | Future check, not MVP blocker. |

## Decision

Adopt unless `@spences10/pi-lsp` covers enough workflow with less setup.
