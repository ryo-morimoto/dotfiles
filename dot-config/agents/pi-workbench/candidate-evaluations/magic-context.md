# Candidate Evaluation: Magic Context

Source: `https://github.com/cortexkit/magic-context`
Current ref: `d9728ce483acd5c49fb0cf3a2d5f7284b81e9872`
Role: context compaction, auto recall hints, project memory, and consolidation.

## Install

Tried: not yet.

Commands to try:

```sh
npx @cortexkit/magic-context@latest setup --harness pi
npx @cortexkit/magic-context@latest doctor --harness pi
```

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| Pi extension installs in disposable config. | pending | Capture generated files. |
| Background compression reduces context pressure. | pending | Need before/after evidence. |
| Auto recall hints are compact and high-confidence. | pending | Tune result count and threshold. |
| Project memory is inspectable and separated. | pending | Record SQLite path if applicable. |
| Doctor command reports healthy setup. | pending | Required for supportability. |
| Duplicate writes with Engram are understood. | pending | Run isolated before combined mode. |

## Decision

Compare after Engram. Use for compaction only if it does not conflict with
durable memory capture.
