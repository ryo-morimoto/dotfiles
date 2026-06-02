# Magic Context Evaluation

Candidate: `cortexkit/magic-context`
Date checked: 2026-05-29
Source checked: GitHub HEAD `d9728ce483acd5c49fb0cf3a2d5f7284b81e9872`

## Contract

- Context compression reduces pressure without hiding critical constraints.
- Project memory is inspectable and separated from user/global memory.
- Auto recall hints are low-volume and high-confidence.
- Doctor command reports setup and memory health.
- Running with Engram does not duplicate writes or inject conflicting hints.

## Install Command To Try

```sh
git clone https://github.com/cortexkit/magic-context /tmp/magic-context
```

Use the published packages:

```sh
npx -y @cortexkit/magic-context setup --harness pi
```

Declare the Pi package through Pi settings:

```json
{
  "packages": ["npm:@cortexkit/pi-magic-context"]
}
```

## Minimal Config To Try

Evaluate in a separate Pi user profile or with Magic Context disabled from the normal profile after the test. Disable
Engram passive writes during this test unless explicitly testing conflicts.

## Smoke Commands

```text
doctor
project memory status
compact current context
search project memory for "test decision"
```

## Observed Behavior

Candidate exists at the checked GitHub HEAD. npm packages exist as `@cortexkit/magic-context@0.21.8` and
`@cortexkit/pi-magic-context@0.21.8`. `npx -y @cortexkit/magic-context --version` returned `0.21.8`.

Engram conflict/duplicate-write behavior was not exercised.

Evidence: current live check output from `pi list`, package help, build output, or candidate notes.

## Disposition

Evaluate after Engram. Adopt only if it clearly owns context compaction or if it can run in a split responsibility model
without duplicate memory writes.

## Local Adapter Justified?

No.
