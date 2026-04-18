---
name: lift-me
description: Find opportunities for lift abstraction in a real codebase or design discussion. Use when the user wants to identify repeated computation structures, raise local patterns into reusable semantic operations, improve reasoning ability, compare similar flows, or decide what should and should not be abstracted.
license: CC0-1.0
metadata:
  author: OpenAI
  version: "1.0"
  style-inspiration: design-an-interface
---

# Lift Me

Find places in a real project where local implementation patterns should be lifted into a shared computational abstraction.

This skill is for **discovery and application**, not abstract theory. Use it when the user wants to:

- inspect a real codebase, module, workflow, or API surface
- find repeated computational structure hiding behind different implementations
- improve local reasoning, refactoring safety, naming consistency, or design conversations
- decide whether something should become `map`/`fold`/`pipeline`/`rule-combinator`/`rangeFold`-like
- separate **lift abstraction** from **encapsulation abstraction**

## Core idea

Do not start by naming category-theory objects.

Start by asking:

1. **What judgment keeps repeating?**
2. **What structure keeps repeating?**
3. **What do we want to preserve across cases?**
4. **What safe rewrites become possible if we name that structure?**

A good lift abstraction does **not** merely rename code. It creates a shared semantic layer that:

- makes multiple cases discussable in the same language
- gives a stable center of gravity for naming and APIs
- improves reasoning before execution
- reduces repeated local branching and ad hoc glue

## Workflow

### 1. Frame the task around concrete artifacts

Anchor the conversation in something real:

- 2-5 similar functions
- several handlers/use-cases/jobs
- multiple query/data-structure APIs
- repeated validation or failure flows
- repeated aggregation/selection/update logic

Ask for or inspect concrete examples before abstracting.

Prompt with questions like:

- "Show me 3 places that feel similar but are currently named differently."
- "Where do reviewers keep making the same comment?"
- "Which parts feel repetitive to modify, compare, or reason about?"
- "Which flows look different in code but feel like the same problem?"

If only one example exists, stay tentative. Lift abstraction is more credible with a small family of examples.

### 2. Separate computation shape from implementation detail

For each example, extract:

1. **Input / output shape**
2. **What can vary**
3. **What must be preserved**
4. **How the steps compose**
5. **Where reasoning currently breaks down**

Then split observations into two piles:

#### Pile A: likely lift candidates

Patterns about the **shape of computation**, such as:

- failure propagation
- optionality / absence
- asynchronous sequencing
- aggregation / folding
- range summarization
- repeated state transitions
- rule composition
- traversal over collections or trees
- effect sequencing
- query planning / transformation pipelines

#### Pile B: likely encapsulation candidates

Patterns about **change boundaries**, such as:

- database vendor details
- HTTP client differences
- queue or cache integration details
- persistence format
- framework wiring
- deployment or infrastructure choices

If the main value is "hide what may change," prefer encapsulation.
If the main value is "unify how we talk about and compose the computation," prefer lifting.

### 3. Name the repeated judgment, not the concrete mechanism

Bad abstraction names cling to implementation.
Good abstraction names describe the semantic job.

Prefer names like:

- `ResultPipeline`
- `RangeFold`
- `RuleSet`
- `AsyncState`
- `BatchTransform`
- `SelectionPolicy`
- `DomainCheck`

Avoid names that merely freeze the current machinery, such as:

- `SegTreeHelper`
- `HttpWrapper`
- `CommonUtils`
- `ValidationManager`

Ask:

- "If the implementation changed completely, would this name still make sense?"
- "Does the name describe what is computed, or only how it happens today?"

### 4. Test whether the abstraction raises reasoning quality

A candidate is promising only if it improves reasoning in at least **two** of these ways:

- lets you compare multiple implementations with one vocabulary
- enables safe local rewrites
- shrinks the number of ad hoc branches in each callsite
- clarifies what laws / invariants / guarantees matter
- makes testing more local and compositional
- gives the team a reusable review lens
- makes the correct choice among variants easier to explain

If it only creates a new wrapper or new jargon, reject it.

### 5. Produce multiple candidate lifts

Do not stop at the first abstraction. Generate **2-3 competing views**.

For each candidate, provide:

1. **What is considered the same across examples**
2. **What differences are intentionally ignored**
3. **The core operation(s)**
4. **What this makes easier to reason about**
5. **What this hides too aggressively or gets wrong**

A useful pattern is:

- Candidate A: narrow, operational, low-risk
- Candidate B: semantic center with better naming
- Candidate C: more ambitious algebraic or compositional view

Then compare them in prose.

### 6. Choose the minimal abstraction that changes team conversation

Prefer the smallest abstraction that noticeably shortens review and design discussions.

Good signs:

- teammates can point to "this is another `RangeFold` case"
- a review comment can refer to the abstraction instead of restating mechanics
- new features slot into an existing semantic shape
- tests can move from scenario-specific to property- or law-oriented checks

### 7. Apply it to one real slice

Do not end at analysis. Rewrite one small representative slice.

For the selected candidate:

1. show the code or design **before**
2. introduce the new semantic operation / interface / type / combinator
3. show the **after** version
4. explain what became easier to state, test, or refactor
5. list what remains concrete and intentionally un-lifted

## Heuristics

### Signals that something should be lifted

- the same kind of branch appears in many places
- callsites repeat the same sequencing pattern
- several implementations answer the same question with different machinery
- the team lacks stable nouns for recurring review conversations
- one concept currently appears as many special cases
- the right choice among multiple strategies can be described by preserved properties

### Signals that something should **not** be lifted yet

- there is only one example
- the shared idea disappears once you remove naming tricks
- every case has different composition rules
- the abstraction would mostly mirror current implementation details
- the cost of explaining the abstraction exceeds the cost of repeating the code

## Output format

When using this skill, structure the response like this:

1. **Observed family**  
   What concrete examples appear related.

2. **Repeated judgment**  
   The question or decision that keeps recurring.

3. **Candidate lifts**  
   2-3 different ways to treat them as the same kind of computation.

4. **Best candidate**  
   Which abstraction to try first and why.

5. **Small application**  
   A tiny before/after using real project material.

6. **Do not lift**  
   What should remain concrete or merely encapsulated.

## Gotchas

- Do not force category-theory vocabulary if the team does not already use it.
- Do not confuse "same dependency" with "same computation shape."
- Do not lift implementation details just because they recur.
- Do not overfit to one subsystem.
- Do not present a giant framework when a small combinator or naming layer is enough.
- Do not ignore the cost of teaching the abstraction to other engineers.

## When useful, load more detail

- Read `references/discovery-prompts.md` when you need sharper questions for exploring a codebase with the user.
- Read `references/evaluation-checklist.md` when choosing between competing candidate abstractions.
- Read `assets/workshop-template.md` when running a live design/refactoring session with a team.
