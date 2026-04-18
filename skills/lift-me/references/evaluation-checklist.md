# Evaluation Checklist

Use this when comparing candidate lift abstractions.

## Primary success signal

**Review / design conversation shortens after introducing the abstraction.**

Before, engineers repeat mechanics:

- "what about null here?"
- "what about the response format?"
- "what about retries?"

After, they refer to the abstraction:

- "this is a `Result` flow"
- "this is a `RangeFold`"
- "this is an effect boundary"

If that shortening cannot be argued concretely, the candidate is not a lift — regardless of how elegant the name or how much code it removes.

## Classification gate (do first)

Before scoring, label every candidate:

- **Lift** — names a repeated judgment or computation shape with preserved invariants
- **Encapsulation** — hides a framework / transport / vendor / format detail
- **Neither** — only removes duplicated lines

Only lift candidates proceed through the rest of this checklist. Encapsulation candidates may still be worth applying, but not as a lift — label honestly (see `lift-vs-encapsulation.md`).

## Semantic strength

- Does it name a real repeated computation shape or judgment?
- Does the name survive implementation replacement (different framework / storage / transport)?
- Can it explain at least three concrete examples from real code?
- Are preserved properties (invariants, laws, guarantees) explicit?

## Reasoning gain (require at least 2)

A candidate is not a lift unless it improves at least **two** of:

- lets multiple implementations be compared using one vocabulary
- exposes preserved invariants
- enables safer local rewrites
- reduces ad hoc branching at callsites
- makes tests more property-oriented
- gives reviewers a reusable semantic lens
- names a domain / computation concept rather than a framework operation

"Less code" alone does not qualify.

## Scope control

- Smallest abstraction that changes how the team talks?
- Avoids swallowing unrelated cases whose invariants actually differ?
- Leaves implementation detail and boundaries in the right place?

## Adoption risk

- Would another engineer understand it from one example?
- Is the name semantic, not mechanistic?
- Is there a small slice where it can be applied first?

## Reject when

- It is mostly a wrapper over framework / transport mechanics.
- It only centralizes code without improving reasoning.
- It requires more theory than its payoff justifies.
- It merges cases whose invariants are actually different.
- Its main justification is "these lines repeat."
- "Review conversation shortens" cannot be argued concretely.
