---
name: lift-me
description: Identify places in a real codebase where reasoning ability can be improved by lifting repeated judgment into a shared semantic operation, and produce a plan for that enhancement. Stronger than refactoring — refactoring preserves behavior; lifting creates a new layer at which the team can reason, compose, and rewrite. Use when identifying repeated judgment, proposing shared semantic operations, comparing similar flows, or deciding what should and should not be abstracted.
license: CC0-1.0
metadata:
  author: OpenAI
  version: "1.2"
  style-inspiration: design-an-interface
---

# Lift Me

Identify places where **reasoning ability (推論可能性)** can be improved by lifting repeated judgment into a shared semantic operation, and produce a **plan** for that enhancement. This is stronger than refactoring: refactoring preserves behavior; lifting creates a new layer at which the team can reason, compose, and rewrite.

## Entry signal

The trigger is **"the discomfort of performing the same reasoning repeatedly"** — not visible code duplication. If callsites look different while the team keeps answering the same question, that is a lift candidate. Callsites that merely share lines are usually only encapsulation candidates.

Central question:

> What computation or judgment does the team need a shared name for?

Not:

> What duplicated implementation can I hide quickly?

Before recommending any change, separate **lift** (names a repeated judgment; survives implementation replacement) from **encapsulation** (hides a framework / transport / vendor / format detail). Both are valuable; only one is a lift. See `references/lift-vs-encapsulation.md`.

## Workflow

1. **Find a family of 3+ examples** in high-yield areas: failure propagation, iteration / aggregation, effect boundaries, state transitions, rule evaluation. Record real file paths, not summaries.

2. **State the repeated judgment in one sentence** without framework, transport, or response-shape vocabulary. For each example, list what must be preserved across implementations (invariants, laws, order, sum / key preservation, absence handling).

3. **Generate 2-3 candidates** (narrow / semantic / ambitious) and classify each as **lift**, **encapsulation**, or **neither**.

4. **Check reasoning gain, not code reduction.** The primary signal is that **review conversation can refer to the abstraction instead of restating mechanics**. See `references/evaluation-checklist.md`.

5. **Produce a plan** (see Acceptance Criteria). Do not apply unless the user explicitly asks; if applying, rewrite one small slice only.

See `references/discovery-prompts.md` for category-specific questions and typical core operations. `assets/workshop-template.md` for live team sessions.

## Acceptance Criteria

Before returning a plan to the user, verify all of:

1. **Family is real** — 3+ concrete examples with file paths or identifiers.
2. **Repeated judgment** stated in one sentence, with no framework / transport / response-shape vocabulary.
3. **Preserved properties listed** for each lift candidate (invariants, laws, guarantees the abstraction must protect across implementations).
4. **3+ candidates compared** (narrow / semantic / ambitious), each explicitly classified as **lift**, **encapsulation**, or **neither**.
5. **Chosen candidate improves at least 2 of:** shared vocabulary across implementations; exposed invariants; safer local rewrites; fewer ad hoc branches at callsites; property-oriented tests; reusable review lens; names a domain / computation concept rather than a framework operation.
6. **Plan deliverable contains all of:**
   - 3+ concrete "before" examples on real paths
   - shared vocabulary paragraph (what is treated as the same; what differences are intentionally ignored)
   - 2-3 core operations — the *composition* rules (map / flatMap / fold / traverse / pipe / allocate / …)
   - 1-2 explicit rewriting rules ("this shape → that abstraction")
   - non-lift boundary (what stays concrete or only encapsulated)
7. **Non-lift outcomes labeled honestly** — encapsulation is not presented as a lift.
8. **Success criterion stated concretely** — exactly how review / design conversation is expected to shorten after introduction. If this cannot be argued, reject the candidate.

If any criterion cannot be met, report the gap and stop before recommending a change.
