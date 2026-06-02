# APM Evaluation

Candidate: `microsoft/apm`
Date checked: 2026-05-29
Source checked: GitHub HEAD `ec771e5760a5aa106a60018599273c955e79d7f1`

## Contract

- `apm.yml` can declare skills, plugins, and MCP servers needed for project use.
- Lockfiles pin dependency versions.
- Audit/policy commands catch drift or insecure package choices.
- Project install does not unexpectedly mutate unrelated live config.

## Install Command To Try

```sh
uvx --from apm-cli apm --help
```

The public npm package `@microsoft/apm` was not available when checked. The repo README documents `pip install apm-cli`
and native install scripts.

## Minimal Config To Try

Use `config.examples/apm/apm.yml` as a non-live example, then run install/audit in a disposable project.

## Smoke Commands

```sh
apm install --dry-run
apm audit
```

Use exact command names from the installed `apm --help`; the above names are the target workflow, not a substitute for
the current CLI help.

## Observed Behavior

Candidate exists at the checked GitHub HEAD. `uvx --from apm-cli apm --help` passed and listed `install`, `audit`,
`compile`, `mcp`, `policy`, and other commands.

Initial dry-run against `config.examples/apm/apm.yml` failed because the example was missing required field `version`.
After correcting the manifest to APM's `dependencies.mcp` shape, `apm install --dry-run --target codex` passed and
reported four MCP dependencies: `codedb`, `lsmcp`, `ai-sessions`, and `engram`.

Evidence: current live check output from `pi list`, package help, build output, or candidate notes.

## Disposition

Adopt as package/distribution layer if the CLI supports project-scoped install and audit. Do not build a local package
manager.

## Local Adapter Justified?

No.
