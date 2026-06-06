# Candidate Evaluation: pi-permission-system

Source: `https://github.com/MasuRii/pi-permission-system`
Current ref: `ccebbf4afce3910f3724829b425093e79b006d3d`
Role: permission filtering and runtime enforcement.

## Install

Tried: not yet.

Command to try:

```sh
pi install npm:pi-permission-system
```

## Policy Baseline

- Allow read-only code exploration.
- Allow local test execution by explicit command patterns.
- Ask for patch/edit/write.
- Ask for destructive local git operations.
- Deny secret reads, credential export, remote publish, package publish,
  deployment, and `git push`.

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| Denied tools are hidden before model start. | pending | Check prompt/tool list. |
| Runtime enforcement blocks forbidden calls. | pending | Use fake secret paths and harmless deny tests. |
| Bash pattern controls distinguish safe and unsafe commands. | pending | Include `git status` vs destructive git examples. |
| MCP tool permissions can be restricted by server/tool. | pending | Test one read-only and one write-like tool. |
| Subagent permission prompts forward to parent. | pending | Depends on subagent candidate. |

## Decision

Use before considering any custom policy engine.
