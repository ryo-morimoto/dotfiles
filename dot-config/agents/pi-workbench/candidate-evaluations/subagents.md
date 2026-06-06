# Candidate Evaluation: pi-subagent

Source: `https://github.com/mjakl/pi-subagent`
Current ref: `b7f0360a4d16ea76e8caff0279373e2b6b9d4977`
Role: Pi subagent extension.

## Install

Tried: not yet.

Commands to try:

```sh
pi install npm:@mjakl/pi-subagent
pi install git:github.com/mjakl/pi-subagent
```

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| Read-only explorer subagent works. | pending | Must not stage or write files. |
| Reviewer/tester subagents can run in parallel. | pending | Use harmless commands. |
| Depth and cycle guards trigger as documented. | pending | Verify default limits. |
| Project-local agent approval is required. | pending | Required before trusting local agents. |
| Parent receives concise final result. | pending | Avoid child trace flooding. |
| Permission requests route to parent where needed. | pending | Coordinate with permission candidate. |

## Decision

Adopt first for subagents. Evaluate `tintinweb/pi-subagents` and
`@spences10/pi-team-mode` only after the minimal extension is tested.
