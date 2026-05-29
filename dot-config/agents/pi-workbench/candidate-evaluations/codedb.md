# codedb Evaluation

Candidate: `justrach/codedb`
Date checked: 2026-05-29
Source checked: GitHub HEAD `e89e110a695ec64de2d3083b31644011457e55eb`

## Contract

- `codedb_context` answers task-shaped codebase context queries.
- `codedb_deps` gives dependency neighborhoods for changed files.
- Snapshots can be created and inspected.
- Sensitive-file blocking is enabled and verified.
- Output is usable as a textual review surface without building a graph viewer.

## Install Command To Try

```sh
git clone https://github.com/justrach/codedb /tmp/codedb
```

Use the repository-documented install/build path. The public npm package name `codedb` is unavailable because it was
unpublished.

## Minimal Config To Try

Register the server as an MCP server in a disposable Pi/MCP config and point it at a non-secret TypeScript or Rust repo.

## Smoke Commands

```text
codedb_context("How is the main entry point wired?")
codedb_deps("src/main.ts")
```

## Observed Behavior

Local `codedb` CLI exists on PATH. `CODEDB_NO_TELEMETRY=1 codedb . tree`, `codedb . search "pi agent workbench"`, and
`codedb . outline dot-config/agents/pi-workbench/README.md` passed.

The source repository exists at the checked HEAD; npm install by package name is not a valid path.

Receipt: `verification/receipts/2026-05-29-local-smoke.md`.

## Disposition

Adopt as code-intelligence candidate. Do not build a local graph engine or viewer for MVP.

## Local Adapter Justified?

No.
