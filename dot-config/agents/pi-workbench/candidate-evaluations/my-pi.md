# my-pi Package Set Evaluation

Candidate: `spences10/my-pi`
Date checked: 2026-05-29

## Packages Checked

| Package | npm version | Node requirement |
| --- | --- | --- |
| `@spences10/pi-mcp` | `0.0.37` | `>=24.15.0` |
| `@spences10/pi-lsp` | `0.0.33` | `>=24.15.0` |
| `@spences10/pi-context` | `0.0.24` | `>=24.15.0` |
| `@spences10/pi-recall` | `0.0.13` | `>=24.15.0` |
| `@spences10/pi-telemetry` | `0.0.23` | `>=24.15.0` |
| `@spences10/pi-redact` | `0.0.12` | `>=24.15.0` |
| `@spences10/pi-skills` | `0.0.28` | `>=24.15.0` |
| `@spences10/pi-team-mode` | `0.0.31` | `>=24.15.0` |

## Contract

- Package install works with current Pi.
- Project/global config is understandable and reproducible.
- MCP config can be project-scoped.
- Telemetry and context data are local and inspectable.
- Redaction runs before logs, memory writes, and session export.

## Config To Try

Declare the package set in Pi settings:

```json
{
  "packages": [
    "npm:@spences10/pi-mcp",
    "npm:@spences10/pi-lsp",
    "npm:@spences10/pi-context",
    "npm:@spences10/pi-recall",
    "npm:@spences10/pi-telemetry",
    "npm:@spences10/pi-redact",
    "npm:@spences10/pi-skills"
  ]
}
```

Evaluate `@spences10/pi-team-mode` only after the minimal subagent path is checked.

## Minimal Profile To Try

Use global `~/.pi/agent/settings.json` for personal defaults. Use project-local `.pi/settings.json` only when a project
needs a distinct package set or team contract.

## Smoke Command

```sh
node --version
pi --version
pi list
```

Then verify each package's documented command or tool registration in Pi.

## Observed Behavior

npm metadata is available and consistently requires Node `>=24.15.0`. Local Node is `v24.15.0`.

Disposable install/list smoke passed for `@spences10/pi-mcp`, `@spences10/pi-lsp`, `@spences10/pi-context`,
`@spences10/pi-recall`, `@spences10/pi-telemetry`, `@spences10/pi-redact`, and `@spences10/pi-skills`. Separate
disposable install/list smoke also passed for `@spences10/pi-team-mode`.

`PI_PACKAGE_DIR` must contain a `package.json`; pointing it at an empty directory fails with `ENOENT`.

Receipt was removed with the throwaway smoke runner; use `pi list` output for the current install state.

## Disposition

Adopt selected packages through Pi settings. The dotfiles repo may add Node runtime prerequisites if needed, but should
not generate live Pi runtime config.

## Local Adapter Justified?

No.
