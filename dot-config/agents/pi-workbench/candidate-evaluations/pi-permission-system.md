# pi-permission-system Evaluation

Candidate: `MasuRii/pi-permission-system`
Date checked: 2026-05-29
Source checked: GitHub HEAD `ccebbf4afce3910f3724829b425093e79b006d3d`

## Contract

- Denied tools are hidden before model start where possible.
- Runtime enforcement blocks forbidden calls even if a tool is visible.
- Bash allow/ask/deny patterns cover common safe and unsafe commands.
- MCP permissions can be restricted by server and tool.
- Subagent permission prompts forward to the interactive parent.

## Install Command To Try

```sh
pi install npm:pi-permission-system
```

The GitHub source is still useful for audits and tests.

## Minimal Policy To Try

```json
{
  "bash": {
    "allow": ["pwd", "ls *", "rg *", "git status *", "npm test"],
    "ask": ["git checkout *", "git merge *", "rm *"],
    "deny": ["git push *", "env", "printenv", "cat ~/.ssh/*"]
  },
  "tools": {
    "read": "allow",
    "edit": "ask",
    "write": "ask",
    "deploy": "deny"
  }
}
```

## Smoke Commands

```sh
pi --permission-profile ./permission.example.json
```

In the session, try a safe read, a test command, an edit, a denied secret read, and a denied push.

## Observed Behavior

Candidate exists at the checked GitHub HEAD. npm package `pi-permission-system@0.6.0` exists. Disposable Pi install/list
smoke passed for `npm:pi-permission-system`.

Runtime allow/ask/deny enforcement was not exercised because it requires an interactive live Pi session.

Receipt: `verification/receipts/2026-05-29-local-smoke.md`.

## Disposition

Adopt before building any local policy engine. Cedar and custom policy languages are out of MVP.

## Local Adapter Justified?

No.
