# Evaluation Checklist

Use this when comparing candidate lift abstractions.

## Semantic strength

- Does it name a real repeated computation shape?
- Does it survive implementation replacement?
- Can it explain at least three concrete examples?

## Reasoning gain

- Does it reduce repeated branchy glue at callsites?
- Does it create safe rewrite rules or laws?
- Does it make tests more compositional?
- Does it shorten design/review discussion?

## Scope control

- Is it the smallest abstraction that changes how the team talks?
- Does it avoid swallowing unrelated cases?
- Does it leave implementation detail and boundaries in the right place?

## Adoption risk

- Would another engineer understand the abstraction from one example?
- Is the name semantic rather than mechanistic?
- Is there a tiny slice where it can be applied first?

## Reject when

- it is mostly a wrapper
- it only centralizes code but does not improve reasoning
- it requires too much theory for too little payoff
- it merges cases whose invariants are actually different
