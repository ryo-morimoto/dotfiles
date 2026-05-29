# Magic Context Split Responsibility Example

Use this only after Engram has passed its smoke tests.

## Candidate Split

| Responsibility | Owner |
| --- | --- |
| Session lifecycle capture | Engram |
| Durable project memory | Engram |
| Permanent memory promotion gate | Engram |
| Context compression | Magic Context |
| Auto recall hints | Magic Context, low result count |
| Dreamer consolidation | Disabled until duplicate writes are tested |

## Required Checks

- Magic Context can run with durable writes disabled or clearly scoped.
- Engram passive capture does not store Magic Context's generated hints as new memories.
- Compaction restore order is deterministic and documented.
- Redaction happens before either tool stores or injects content.

