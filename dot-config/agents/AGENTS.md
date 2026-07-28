Respond in Japanese by default. Switch languages only when the user explicitly requests another language.

## Naming And Vocabulary

Treat names and vocabulary as part of the design, domain model, and user-facing contract. A change is not complete merely because it works: every affected name must communicate its meaning precisely at its point of use.

### Trigger

Apply this section before introducing or changing any non-trivial term, abbreviation, module, type, function, method, field, event, API or schema element, configuration or CLI key, metric, error, test name, or documentation term. This includes adding, renaming, repurposing, translating, pluralizing, abbreviating, broadening, or narrowing a term, even when naming is incidental to a larger task.

Do not require candidate comparison for generated or vendored code, names fixed by a language or framework, established ecosystem terms of art, or conventional locals whose meaning is completely constrained by a tiny scope, such as `i` in a short loop. Never preserve a misleading name merely because it falls into one of these categories.

### Required Procedure

1. **Search first.** Search the repository for the proposed term, prior terms, inflections, abbreviations, synonyms, and adjacent concepts. Inspect representative declarations and use sites across code, tests, docs, schemas, configuration, events, and telemetry rather than judging a declaration in isolation.
2. **Define the concept.** State in one sentence what the term means, what it includes, what it excludes, and the bounded context in which that meaning holds. If this cannot be stated, investigate the responsibility and domain before naming it.
3. **Classify the surface.** Determine whether the name is local/private, shared repository vocabulary, or an external, public, serialized, or persisted contract. Treat renames in the last category as compatibility and migration work, not cosmetic edits.
4. **Choose concepts before words.** Decide which concepts the name must express, then choose the canonical word for each concept, then compose the identifier according to the language. Reuse an existing term only when it expresses exactly the same concept. Do not create a synonym for novelty or convenience.
5. **Compare in context.** For a new non-trivial term, compare at least two serious candidates at the declaration, representative call sites, tests, errors, and documentation prose. Prefer the candidate that makes intent and actual behavior agree naturally at use sites.
6. **Use difficulty as design feedback.** If every honest name is long, the definition is unstable, or only vague words such as `Manager`, `Util`, `Data`, `Info`, `Item`, `Process`, or `Handle` seem available, investigate mixed responsibilities, a misplaced boundary, or a missing domain abstraction before abbreviating or polishing the ambiguity away.
7. **Keep the vocabulary coherent.** Within one bounded context, use one canonical term for one concept and one meaning for one term. Propagate the chosen vocabulary consistently through code, tests, APIs, schemas, configuration, CLI surfaces, events, telemetry, and documentation. Preserve established terms of art when their established meaning is intended.
8. **Verify the result.** Search again for stale names, rejected synonyms, and conflicting uses. For public or persisted names, identify callers and consumers and verify the compatibility, alias or deprecation, migration, and release-note strategy.

### Decision And Escalation

- For reversible local or private naming decisions, choose the most precise name supported by the procedure and proceed without waiting for approval.
- Ask only when the domain meaning has multiple plausible interpretations, when the change would merge or split established concepts, or when a public or persisted rename lacks an agreed compatibility strategy. Present the competing definitions, best candidates, consequential difference, and migration impact.
- When naming exposes a small design problem within task scope, fix that problem. Ask before expanding into an API, schema, permission-boundary, or other non-obvious structural change.

### Calibration

- Reject `processData()` because neither the subject, transition, nor outcome is clear. Prefer a truthful name such as `captureAuthorizedPayment()` when that is the actual behavior.
- Reject `returnsCorrectResult` because `correct` delegates the meaning to the reader. Prefer an observable statement such as `rejectsExpiredAccessToken`.
- Accept `invoice.total()` when the receiver supplies the context; `calculateInvoiceTotal()` would repeat it.
- Accept `i` in a short conventional loop whose scope completely determines its meaning.
- Do not mechanically replace a public `userId` with `accountId` merely because the words appear related. Establish the conceptual difference and migration impact first.

### Completion Evidence

When a task introduces or changes a non-trivial term, include in the final report the chosen term and its one-sentence definition, the important alternative rejected and why, the surfaces searched or updated, and any compatibility impact. Omit this bookkeeping for conventional tiny-scope locals.
