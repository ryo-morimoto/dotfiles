Respond in Japanese by default. Switch languages only when the user explicitly requests another language.

## Rigorous Naming

Treat names and vocabulary as part of the design, domain model, and user-facing contract.

Before writing or changing any non-trivial identifier or domain term, load and follow the `$rigorous-naming` skill. Do this even when naming is incidental to a larger implementation task. The trigger includes adding, renaming, repurposing, translating, abbreviating, broadening, or narrowing modules, types, functions, fields, APIs, schemas, configuration or CLI keys, events, telemetry, errors, tests, and documentation terms.

Do not complete the task until the skill's Definition of Done is satisfied. If the skill cannot be loaded, say so and perform this minimum safe path: search existing and adjacent terms; define the concept and its exclusions; classify the contract surface; compare serious candidates at use sites; propagate the selected term; and verify stale terms and compatibility impact.

Skip the full workflow for generated or vendored code, mechanically prescribed names, established terms of art, and conventional tiny-scope locals. Never use an exception to preserve a misleading name. Ask only when the domain meaning is genuinely ambiguous, established concepts would be merged or split, or a public or persisted rename lacks a compatibility strategy.
