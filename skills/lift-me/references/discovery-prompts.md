# Discovery Prompts

Use these prompts to inspect a real project and surface lift candidates.

## Find repeated judgment

- Which decision keeps getting reimplemented?
- Where do engineers keep restating the same reasoning in PRs?
- Which code paths differ in mechanics but answer the same question?
- Which flows feel "obviously related" but have no shared name?

## Probe composition

- What always happens before this step can proceed?
- What stops the pipeline early?
- What gets accumulated, combined, or summarized?
- What gets traversed the same way across multiple modules?
- What is the unit operation and what is the combining operation?

## Separate lift from encapsulation

Ask both:

- If we changed the implementation, would the same abstraction still be useful?
- If the only benefit is hiding a volatile dependency, is this really encapsulation instead?

## Find reasoning pain

- Where does local reasoning fail because too much context is needed?
- Which tests are repetitive because the same structure is expressed ad hoc?
- Where do engineers struggle to explain why one strategy is chosen over another?

## Candidate families to inspect

- validation chains
- request/response handlers
- query building and filtering
- event processing pipelines
- range query APIs
- retry/fallback logic
- state transition code
- policy/rule evaluation
- batch import/export flows
