# Subagents Evaluation

Primary candidate: `mjakl/pi-subagent`
Date checked: 2026-05-29
Source checked: GitHub HEAD `b7f0360a4d16ea76e8caff0279373e2b6b9d4977`

Secondary candidates:

- `tintinweb/pi-subagents`
- `@spences10/pi-team-mode` npm `0.0.31`

## Contract

- Read-only explorer subagent works.
- Reviewer/tester subagents can run in parallel.
- Depth and cycle guards prevent runaway nesting.
- Project-local agent approval is required.
- Permission requests from subagents route to the parent where needed.
- Parent receives a compact final result without child tool trace flood.

## Install Command To Try

```sh
git clone https://github.com/mjakl/pi-subagent /tmp/pi-subagent
```

Use the published package through Pi settings:

```json
{
  "packages": ["npm:@mjakl/pi-subagent"]
}
```

## Minimal Config To Try

Enable one read-only explorer role and one reviewer role. Keep writes disabled for child agents until permission
forwarding is verified.

## Smoke Commands

```text
spawn role=explorer task="summarize repo structure"
spawn role=reviewer task="review this markdown-only diff"
fork role=tester task="run read-only checks"
```

## Observed Behavior

The primary source repository exists at the checked HEAD. npm package `@mjakl/pi-subagent@2.1.0` exists. User profile
install/list smoke passed for `npm:@mjakl/pi-subagent`.

Spawn/fork behavior was not exercised because it requires an authenticated live Pi run.

Evidence: current live check output from `pi list`, package help, build output, or candidate notes.

## Disposition

Adopt `mjakl/pi-subagent` first. Evaluate `@spences10/pi-team-mode` only if it provides clearer coordination or better
permission forwarding.

## Local Adapter Justified?

No.
