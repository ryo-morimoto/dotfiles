# Lift vs Encapsulation

A lift abstraction names a repeated **judgment or computation structure** with preserved invariants. An encapsulation abstraction hides an **implementation, framework, or transport detail**. Both reduce code, but only one creates a new semantic layer.

Confusing the two is the most common failure of `lift-me`: visible duplicated code is extracted into a helper, and the helper is labeled a lift even though it only hides framework mechanics.

## Definitions

**Lift candidate**
- Main value: gives a shared name to a repeated judgment, computation shape, or preserved property.
- Survives implementation replacement: if the framework / HTTP layer / storage / queue changed wholesale, the name still makes sense.
- Enables reasoning: callsites can be discussed in terms of the name, not the mechanics.

**Encapsulation candidate**
- Main value: hides an implementation or boundary detail so that change is localized.
- Tied to a specific mechanism (framework, vendor, transport, format).
- If the mechanism changes, a different adapter replaces it rather than the same abstraction being reused.

## Discriminator questions

Ask all of these for each candidate:

1. **Does the name describe what is computed, or how it is currently done?**
   Machinery words (HTTP, headers, SQL, queue, file, response, request) point to encapsulation.

2. **Can you describe the pattern without referring to the current framework or transport?**
   If not, it is encapsulation.

3. **Are there preserved properties — invariants, laws, or guarantees — that multiple implementations would have to respect?**
   If yes, it is a lift candidate.

4. **If two teams implemented it differently, would the shared name still let them compare approaches?**
   If yes, it is a lift.

5. **What happens to the abstraction if you swap the underlying mechanism for something very different?**
   - Lift: still meaningful, same name.
   - Encapsulation: replaced by a different adapter with a different name.

## Honest labeling

If the best available change is encapsulation, apply it and call it encapsulation. Do not inflate it into a lift.

An encapsulation helper is still valuable — it localizes change, reduces noise, and clarifies boundaries. The mistake is only in promoting it to a role it does not play.

## Common false positives (not lifts)

- Helpers that wrap framework response construction
- Thin adapters over third-party SDKs
- Utility methods that rename a sequence of stdlib calls
- Base classes that collect cross-cutting framework concerns
- "Manager" / "Helper" / "Utils" / "Common" that concentrate unrelated code by proximity
- Controller / handler convenience methods that only hide transport details
- **Small-class extraction that relocates wiring without introducing a law** — see next section

Some of these are legitimate encapsulations. None of them are lifts.

## Small-class extraction — a recurring false positive

Extracting a small class to host a sequence of calls (e.g. `allocations → items / location_ids / ratios → SyncRuleService`) feels like progress because structure visibly increases. It only earns the word "lift" when **all** of these hold:

1. the new class names a **judgment** the team already recognizes as the same across callsites (not merely a code shape the author spotted),
2. at least one **law or invariant** is now enforced or advertised by the class (sum preservation, key preservation, totality, ordering, absence handling, …), AND
3. reviewers will stop re-reading the wiring and instead ask whether the law holds.

If the class only reroutes the same inputs to the same downstream call, with no new invariant and no pre-existing shared mental model, it is **wiring relocation**. The honest labels are:

- **Encapsulation**, if it genuinely localizes a boundary (framework, vendor, transport).
- **Structure cost with no payoff**, if it does not even do that.

Neither is a lift. When the team does not yet share the mental model, do **not** start with a class. Produce a memo, a review-lens checklist, or a workshop first; let the shared noun form in human conversation before it appears in the code.

A lift introduced before its mental model exists reads as noise, not as a shared vocabulary — reviewers still re-read the mechanics, and the cost of the extra class is paid without the reasoning-ability gain.

## What a real lift usually looks like

- Names a **decision** the system keeps making (which bucket, which allocation, which result shape, which outcome)
- Carries **invariants** the name advertises (sum preservation, key preservation, ordering, monotonicity, absence handling, totality)
- Has **at least three distinct callsites** whose mechanics differ but whose judgment is the same
- Lets tests move from scenario-specific assertions toward property-oriented ones
- Gives reviewers a shared noun they can point at instead of restating mechanics

## Required checkpoint before applying

Before making a code change, the answer to each of the following must be explicit:

1. the repeated judgment (one sentence, no framework vocabulary)
2. the computation shape (inputs, outputs, composition)
3. what varies across cases
4. what must be preserved
5. what safe local rewrites the abstraction enables
6. why this is not merely a wrapper over current mechanics

If any answer is missing, stop and investigate; do not extract.
