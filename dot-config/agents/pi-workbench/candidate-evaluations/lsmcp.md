# lsmcp Evaluation

Candidate: `mizchi/lsmcp`
Date checked: 2026-05-29
Source checked: GitHub HEAD `f2fb91d205c19ffff3be1d6f98bdc130b6e8868f`

## Contract

- Project overview works.
- Symbol search and symbol details work in TypeScript and MoonBit repos.
- Diagnostics are available and actionable.
- Rename and references work through the LSP server.
- The tool complements `codedb` instead of replacing it.

## Install Command To Try

```sh
git clone https://github.com/mizchi/lsmcp /tmp/lsmcp
```

Use the npm package:

```sh
npx -y @mizchi/lsmcp --help
```

## Minimal Config To Try

Register `lsmcp` as an MCP server for one TypeScript repo and one MoonBit repo. Ensure each language server is installed
by the normal project toolchain rather than vendored here.

## Smoke Commands

```text
get_project_overview()
search_symbols("main")
get_symbol_details("main")
diagnostics()
```

## Observed Behavior

The source repository exists at the checked HEAD. npm package `@mizchi/lsmcp@0.10.0` exists, requires Node `>=22.0.0`,
and `npx -y @mizchi/lsmcp --help` passed. Help lists `init`, `index`, `doctor`, and presets including `tsgo`,
`typescript`, `rust-analyzer`, `gopls`, and `moonbit`.

Project LSP MCP tool calls were not exercised.

Receipt: `verification/receipts/2026-05-29-local-smoke.md`.

## Disposition

Adopt directly for LSP-grounded code intelligence if install is straightforward. Keep `@spences10/pi-lsp` as the simpler
Pi-native alternative if it covers enough workflow.

## Local Adapter Justified?

No.
