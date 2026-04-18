# Discovery Prompts

Use these prompts to find lift candidates in a real project.

The goal is to find **repeated judgment / repeated reasoning**, not repeated code. Callsites that look different while the team keeps answering the same question are the strongest signal.

## Entry signal

Listen for the discomfort of performing the same reasoning repeatedly:

- "I keep writing the same kind of null / empty / Result check here."
- "Every handler does this before-and-after shaping the same way."
- "We keep traversing this tree / array / range with the same shape."
- "We keep aggregating / selecting / allocating with the same structure."
- "We keep branching on the same kind of condition with different mechanics."

Visible code duplication is a weaker signal and often points at encapsulation rather than a lift.

## Find repeated judgment

- Which decision keeps getting reimplemented with different mechanics?
- Where do engineers keep restating the same reasoning in PRs?
- Which code paths differ in machinery but answer the same question?
- Which flows feel "obviously related" but have no shared name?
- Where do teammates informally say "this is like that other thing"?

## Probe computation shape

- What always must happen before this step can proceed?
- What stops the flow early, and for what reason?
- What gets accumulated, combined, summarized, or allocated?
- What gets traversed the same way across modules?
- What is the unit operation, and what is the combining operation?
- What invariants must still hold if the implementation changed completely?
- What would the abstraction make us *stop seeing* (and is that acceptable)?

## Separate lift from encapsulation

- If we swapped the framework / transport / vendor, would the abstraction still be useful?
  - Yes → lift candidate.
  - No → encapsulation candidate.
- If the only benefit is hiding a volatile boundary, label it encapsulation honestly.

See `lift-vs-encapsulation.md` for the full discriminator.

## High-yield categories

Lift candidates most often live in the five categories below. Typical core operations are hints — not mandatory names.

### 1. Failure propagation
- Signals: `if err != nil`, early `return`, null checks, exceptions, validation chains.
- Look for: **composition rules for possibly-failing computation**, not the site of failure itself.
- Typical shape: `Result`, `Either`, validation pipeline.
- Core ops: `map`, `flatMap`, `traverse`, `recover`.

### 2. Iteration and aggregation
- Signals: list processing, batch jobs, search result aggregation, event aggregation, range queries.
- Look for: **the structure being folded**, not the data source.
- Typical shape: `Fold`, `RangeFold`, `Traversal`, allocation / distribution.
- Core ops: `map`, `fold` / `reduce`, `scan`, `rangeFold`, `allocate`.

### 3. Effect boundaries
- Signals: DB, HTTP, queue, file, clock, random, transaction.
- Look for: **the boundary as a typed context**, not merely "hide a vendor". Lifting is justified when the boundary enables reasoning about purity, sequencing, or resource safety.
- Typical shape: effect type, context, interpreter.
- Core ops: `runX`, `withX`, `bracket`.
- Caution: "wrap this SDK" alone is encapsulation, not a lift.

### 4. State transitions
- Signals: UI state, workflow, approval flow, job state, saga.
- Look for: **the transition structure**, not the number of states.
- Typical shape: state machine, `AsyncState`.
- Core ops: `transition`, `step`, `on(event)`.

### 5. Rule evaluation
- Signals: authorization, billing, discount, feature flags, shipping conditions.
- Look for: **composable predicates / rule set**, not a forest of `if`.
- Typical shape: `Rule`, `Policy`, `Predicate`.
- Core ops: `and`, `or`, `not`, `evaluate`.

## Usually encapsulation, not lifts

- framework response construction and header plumbing
- HTTP / gRPC / queue / cache client wrappers
- persistence format adapters
- vendor SDK facades
- deployment / infrastructure glue
- controller or handler convenience methods

## Reasoning-pain questions

- Where does local reasoning fail because too much context is needed?
- Which tests are repetitive because the same structure is expressed ad hoc?
- Where do engineers struggle to explain why one strategy is chosen over another?
- Which review comments keep recurring because no shared noun exists?
