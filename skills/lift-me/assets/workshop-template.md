# Lift Me Workshop Template

Use this template in a live conversation with a team. The output is a **plan**, not an applied refactor.

## Step 1: Bring examples

Collect 3 examples where the team keeps performing the same reasoning (file paths on real code).

1. 
2. 
3. 

## Step 2: Describe each example briefly

For each:

- Input:
- Output:
- Key steps:
- What can fail / vary / branch:
- What is combined, summarized, selected, or allocated:
- Current mechanics (framework, transport, storage):

## Step 3: State the repeated judgment

In one sentence, the question being answered across the examples.

Rule: no framework, transport, or response-shape vocabulary. If the sentence collapses without those words, this is encapsulation, not a lift.

Repeated judgment:

Preserved across all examples (invariants, laws, order, sum / key preservation, absence handling):

## Step 4: Classify the surface candidates

For each candidate already in mind, label it:

- [ ] Lift — names the repeated judgment; survives implementation replacement
- [ ] Encapsulation — hides a framework / transport / vendor / format detail
- [ ] Neither — only removes duplicated lines

Candidate:             Label:
Candidate:             Label:
Candidate:             Label:

## Step 5: Generate candidates

At least three, spanning narrow / semantic / ambitious.

### Candidate A (narrow / operational)
- Shared computation shape:
- Core operations (map / flatMap / fold / traverse / pipe / allocate / …):
- Preserved properties:
- What becomes easier to reason about:
- What this misses:

### Candidate B (semantic center)
- Shared computation shape:
- Core operations:
- Preserved properties:
- What becomes easier to reason about:
- What this misses:

### Candidate C (more ambitious / compositional)
- Shared computation shape:
- Core operations:
- Preserved properties:
- What becomes easier to reason about:
- What this misses:

## Step 6: Produce the plan

Minimum artifacts:

- **3+ before examples** (real code paths):
- **Shared vocabulary** (1 paragraph — what is treated as the same; what differences are ignored):
- **2-3 core operations** (the composition rules):
- **Rewriting rules** (1-2 "this shape → that abstraction"):
- **Non-lift boundary** (what stays concrete or only encapsulated):
- **Classification** (lift + preserved properties, or honest encapsulation label):

## Step 7: Success criterion

State concretely how review / design conversation is expected to shorten.

Before, engineers discussed:
After, they can say:

If this cannot be argued concretely, reject the candidate.

## Step 8: Validate after one trial refactor (optional)

If the user chooses to apply on one slice:

- Did naming improve?
- Did review discussion shorten?
- Did tests become more property-oriented?
- Did we gain any safe rewrite rules?
- Did we accidentally hide something important?
- Did we inflate an encapsulation into a lift?
