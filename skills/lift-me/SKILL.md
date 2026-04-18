---
name: lift-me
description: Identify places in a real codebase where reasoning ability can be improved by lifting repeated judgment into a shared semantic operation, and return either a plan for that enhancement or a reasoned decision to discuss-first / not-lift before changing code. Stronger than refactoring — refactoring preserves behavior; lifting creates a new layer at which the team can reason, compose, and rewrite. Stopping before an unnecessary abstraction is a valid outcome. Use when identifying repeated judgment, proposing shared semantic operations, comparing similar flows, or deciding what should and should not be abstracted.
license: CC0-1.0
metadata:
  author: OpenAI
  version: "1.3"
  style-inspiration: design-an-interface
---

# Lift Me

Identify places where **reasoning ability (推論可能性), composability (合成可能性), and law-ness (法則性)** can be improved by lifting repeated judgment into a shared semantic operation, and produce a **plan** for that enhancement. Abstraction is **not** the goal — those three properties are. Lifting is stronger than refactoring: refactoring preserves behavior; lifting creates a new layer at which the team can reason, compose, and rewrite.

Use lifting **only** when agents or engineers are repeatedly reviewing the same mental model at the same granularity. Code similarity, duplication, or "could be a helper" alone is **not** a lift signal.

## Entry protocol (run first, always)

Before any analysis, classify the invocation:

### Step 1 — Check whether the user has a concrete purpose

Examples of a real purpose:
- "Review load on this family of changes is too high."
- "I want this judgment to be composable with others."
- "We re-verify the same invariant every change."
- "We keep re-evaluating safety on the same axis."

### Step 2a — Purpose is clear

Judge **lift / encapsulation / neither** strictly against that purpose. Propose an abstraction **only** if it raises reasoning-ability, composability, or law-ness *for that purpose*. Otherwise say so and stop.

**Surface-framing trap.** "Is X a lift?" with only a visible pattern as motivation (no review-load pain, no composition goal, no invariant re-check pressure) is **not** a concrete purpose. Drop back to Step 2b, or — if the question is specifically about X — evaluate X alone and expect a `do not lift` outcome.

### Step 2b — No purpose; user asked "scan the codebase for candidates"

**Do not jump to an implementation plan.** Instead:

1. Scan the codebase and surface **multiple** candidates.
2. For each candidate, state:
   - the repeated mental model
   - the reasoning-ability gained by lifting it
   - whether composability or law-ness actually increases (be honest if not)
   - the **Candidate Rubric** (see Workflow step 3): Team Mental Model Readiness, Review Conversation Gain, Structure Cost, Stop Recommendation
   - the decision criteria used
   - adopted / rejected options and their trade-offs
   - the boundary where it should stay as a helper or encapsulation instead
3. Stop before writing a rewrite plan. Ask the user which candidate (if any) to advance — and note that **"do not lift"** and **"discuss first"** are equally valid outcomes.

### Step 3 — Success condition (applies to every recommendation)

A lift is only worth proposing if it shifts review conversation from
**"let me re-read the implementation details"** to
**"does this satisfy the abstraction's laws / invariants?"**.

If you cannot describe that shift concretely for a candidate, do not recommend it as a lift.

**Deciding not to lift — or deciding to discuss before implementing — is itself a successful outcome.** A skill run that ends in "candidate looked promising on paper, but implementing it would only add structure without raising reasoning-ability" has done its job. An abstraction you chose *not* to introduce is cheaper than one you have to retract.

## Central question

> What computation or judgment does the team need a shared name for so that review stops re-reading mechanics?

Not:

> What duplicated implementation can I hide quickly?

Before recommending any change, separate **lift** (names a repeated judgment; survives implementation replacement) from **encapsulation** (hides a framework / transport / vendor / format detail) from **neither** (keep concrete). All three are legitimate outcomes; only one is a lift. See `references/lift-vs-encapsulation.md`.

## Behaviors to avoid

- Calling duplication a lift the moment it is spotted.
- Calling helper extraction, framework wrapping, or ORM hiding a lift.
- Treating "introduce an abstraction" as the goal.
- Advancing to an implementation plan while no purpose has been established.
- **Small-class extraction that only relocates wiring** (e.g. `allocation → items/locations/ratios → downstream service` moved verbatim into a new class) without exposing a new law or invariant. This is encapsulation at best, pure structure cost at worst — never a lift.
- Advancing to implementation while the team does **not yet share the mental model**. In that state, the class or function being introduced carries no shared meaning, so reviewers still re-read mechanics and the lift fails to pay off. Propose a memo, review-lens checklist, or workshop first.

## Behaviors to prefer

- Check purpose first; if absent, stay in candidate-and-trade-off mode.
- Classify each candidate honestly as lift / encapsulation / neither.
- State exactly how review conversation shortens after the lift lands.
- Reject candidates where that shortening cannot be described.

## Workflow

Run this **after** the entry protocol. If no purpose was given, stop at step 3 and return candidates with trade-offs (Step 2b) — do not continue to step 5.

1. **Find a family of 3+ examples** in high-yield areas: failure propagation, iteration / aggregation, effect boundaries, state transitions, rule evaluation. Record real file paths, not summaries.

2. **State the repeated judgment in one sentence** without framework, transport, or response-shape vocabulary. For each example, list what must be preserved across implementations (invariants, laws, order, sum / key preservation, absence handling).

3. **Generate 2–3 candidates** (narrow / semantic / ambitious). For each, classify as **lift / encapsulation / neither** AND score the **Candidate Rubric**:

   - **Team Mental Model Readiness** — `high` / `medium` / `low`
     - `high`: the concept already appears in review comments, docs, or naming across the team.
     - `medium`: one or two people use it; the team has not converged on the word.
     - `low`: the name is being proposed for the first time; no prior shared usage.
     A lift introduced at `low` / `medium` adds a class the team does not yet mean the same thing by.
   - **Review Conversation Gain** — `concrete` / `speculative` / `weak`
     - `concrete`: you can write the exact sentence reviewers will say post-lift (e.g. "does this preserve the allocation sum?").
     - `speculative`: you can only predict that reviewers "will probably think in these terms."
     - `weak`: you cannot name a review behavior that shortens after the lift lands.
   - **Structure Cost** — `low` / `medium` / `high`
     - `low`: one value or function, one test module, ≤2 callsite rewrites.
     - `medium`: one new class or module, new test file, 3–5 callsite rewrites, new import edges.
     - `high`: multiple new classes, inheritance hierarchy, cross-package restructure, or team onboarding needed.
   - **Stop Recommendation** — `implement` / `discuss first` / `do not lift`. Evaluate in this order; first match wins:
     1. `do not lift` — gain **weak**, or structure cost exceeds reasoning gain, or the candidate is only rewiring allocation → downstream. Keep the code concrete; if cleanup is warranted, label it encapsulation or helper and stop there. **`weak` gain takes precedence over any readiness score** — if no reviewer behavior shortens, no amount of discussion will make the lift useful.
     2. `discuss first` — readiness **low/medium** AND gain at least **speculative** (not `weak`). Produce a pre-implementation artifact **before** touching code. Choose by scope:
        - **Memo** (default) — ≤3 callsites, 1 team, async review acceptable.
        - **Review-lens checklist** — new callsites will keep appearing during the discussion window; the checklist lets PR reviewers apply the forming lens before it is formal.
        - **Workshop** — ≥2 teams, the judgment spans boundaries (auth, payments, safety), or a prior memo circulation failed to converge.
     3. `implement` — readiness **high**, gain **concrete**, cost proportionate to gain.

   **Small-class falsification check.** Before accepting a candidate that introduces a new class or module: ask whether, if you stripped the class away, the remaining flow would be the same inputs going to the same outputs. If yes, and no new law/invariant is enforced by the class, it is wiring relocation — prefer `do not lift` or `discuss first`.

4. **Check reasoning gain, not code reduction.** The primary signal is that **review conversation can refer to the abstraction instead of restating mechanics**. Verify the Rubric: readiness must actually be `high` (or path-to-high must be named), gain must be `concrete`, and cost must be justified by gain. See `references/evaluation-checklist.md`.

5. **Produce the appropriate deliverable.** The artifact (plan or Stop Report) is returned **as text in the response** — do not write it to a file unless the user explicitly requests one. **Applying code changes is separate and always requires explicit user confirmation.**
   - If every candidate landed on `discuss first` or `do not lift`: return a **Stop Report** — the rubric scores, the reason implementation was rejected, and (for `discuss first`) the concrete pre-implementation artifact to produce (memo outline, review-lens bullets, workshop agenda). Do not produce a code plan.
   - If at least one candidate is `implement`: produce a **plan** artifact (see Acceptance Criteria). The plan is a document, not a code change. **Do not apply / edit any code** unless the user explicitly asks after seeing the plan; when applying, rewrite one small slice only.

See `references/discovery-prompts.md` for category-specific questions and typical core operations. `assets/workshop-template.md` for live team sessions.

## Acceptance Criteria

Applies only when returning a **plan** (Stop Recommendation = `implement`, either from an explicit purpose or a user-confirmed candidate). Candidate-only and Stop-Report responses follow Step 2b / Workflow step 5 instead.

Before returning a plan, verify all of:

0. **Purpose stated** — the concrete user problem this lift addresses (review load, composition, invariant re-check, safety axis, …). If missing, drop back to Step 2b.
1. **Family is real** — 3+ concrete examples with file paths or identifiers.
2. **Repeated judgment** stated in one sentence, with no framework / transport / response-shape vocabulary.
3. **Preserved properties listed** for each lift candidate (invariants, laws, guarantees the abstraction must protect across implementations).
4. **2–3 candidates compared** (narrow / semantic / ambitious), each explicitly classified as **lift / encapsulation / neither** AND scored on the **Candidate Rubric** (Team Mental Model Readiness, Review Conversation Gain, Structure Cost, Stop Recommendation). Matches the count in Workflow step 3 — do not inflate to hit an artificial "3+".
5. **Rubric supports implementation** — the chosen candidate is scored `Team Mental Model Readiness: high`, `Review Conversation Gain: concrete`, and Structure Cost is justified by the gain. If readiness is `low/medium` or gain is `speculative`, return a Stop Report instead.
6. **Chosen candidate improves at least 2 of:** shared vocabulary across implementations; exposed invariants; safer local rewrites; fewer ad hoc branches at callsites; property-oriented tests; reusable review lens; names a domain / computation concept rather than a framework operation.
7. **Plan deliverable contains all of:**
   - 3+ concrete "before" examples on real paths
   - shared vocabulary paragraph (what is treated as the same; what differences are intentionally ignored)
   - 2-3 core operations — the *composition* rules (map / flatMap / fold / traverse / pipe / allocate / …)
   - 1-2 explicit rewriting rules ("this shape → that abstraction")
   - non-lift boundary (what stays concrete or only encapsulated)
8. **Non-lift outcomes labeled honestly** — encapsulation is not presented as a lift; wiring relocation is not presented as a lift.
9. **Success criterion stated concretely** — exactly how review / design conversation is expected to shorten after introduction. If this cannot be argued, reject the candidate.

If any criterion cannot be met, return a **Stop Report** (reason, rubric scores, and for `discuss first` the pre-implementation artifact to produce) rather than a code plan. Stopping before a change is a valid outcome of this skill, not a failure.

## Stop Report deliverable

Applies when the chosen outcome is `discuss first` or `do not lift`. Mirrors the plan deliverable at lower cost — include all of:

1. **Purpose stated** — the user question or pressure that led to the scan.
2. **Candidate(s) considered** — 1–3 concrete proposal(s), each with file paths or identifiers. When the user asks about a single named candidate ("is X a lift?"), 1 is acceptable; when scanning for candidates, match Workflow step 3 (2–3).
3. **Small-class falsification result** — did stripping the proposed abstraction leave inputs / outputs unchanged? If yes, call out wiring relocation explicitly.
4. **Rubric scores** — the 4 axes for each candidate, with a one-line justification per axis (anchored to the definitions in Workflow step 3).
5. **Classification** — one of:
   - `lift` (would be a real lift if readiness were raised — the repeated judgment exists, the invariants are nameable, but the mental model is not yet shared; pair with Stop Recommendation `discuss first`).
   - `encapsulation` (hides a framework / transport / vendor / format boundary; implement as a named encapsulation, not a lift).
   - `neither` (no shared judgment AND no boundary — pure structure cost; pair with Stop Recommendation `do not lift`).
   State why the chosen outcome is not `implement`.
6. **Pre-implementation artifact** (required only when Stop Recommendation = `discuss first`) — the concrete memo outline / review-lens bullets / workshop agenda the user should produce before any code change. Include:
   - which callsites to cite,
   - which invariants or definitions the team must agree on,
   - the decision record the artifact should produce (options, chosen option, who, when).
7. **Success criterion for the report itself** — the observable change that would signal the team is now ready to revisit implementation (e.g. "next PR review references the agreed invariant rather than re-reading the arithmetic").

Do not include a code plan. If you find yourself drafting one, the correct outcome was `implement`, not `discuss first`.
