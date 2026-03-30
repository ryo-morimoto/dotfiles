---
name: domain-modeling
description: This skill should be used when designing, refining, or reviewing domain models using type-driven development. It applies when defining type structures for a problem space, converting business concepts into algebraic data types (sum/product/wrapper types), identifying type mismatches in existing code, or iteratively improving type safety. Triggers on "domain modeling", "型設計", "型定義", "ドメインモデル", "make illegal states unrepresentable", "parse don't validate", requests to define types for a new feature, or when reviewing code for type safety improvements. First-class support for TypeScript and MoonBit.
---

# Domain Modeling

Iterative type-driven domain modeling: transform a problem space into compiler-verifiable type definitions and function signatures, then refine through implementation feedback loops.

## Supported Languages

| Language | Product type | Sum type | Wrapper type | Result | File ext |
|---|---|---|---|---|---|
| **TypeScript** | `type T = { a: A; b: B }` | `type T = A \| B` (discriminated union) | `Brand<T, "Name">` | User-defined (see below) | `.ts` |
| **MoonBit** | `struct T { a: A; b: B }` | `enum T { A; B(C) }` | `struct T(Inner)` (newtype) | Built-in `Result[T, E]` | `.mbt` |

Adding a new language: create a `references/<lang>-patterns.md` with foundational types, conversion examples, and placeholder syntax. Update `scripts/measure_metrics.sh` with grep patterns.

## When to Use

- Starting a new module, service, or feature that needs type definitions
- Reviewing existing code for type safety gaps (string-typed status fields, optional fields that depend on state, etc.)
- Converting informal requirements into typed data structures
- Refactoring types after discovering mismatches during implementation

## Initial Setup

Before starting, confirm with the user:

1. **Target directory** — where type files live or will be created (e.g. `src/domain/`)
2. **Language** — `ts` (TypeScript) or `mbt` (MoonBit)
3. **Scope** — full system or a specific subsystem
4. **Output file** — write types to a file (e.g. `src/domain/types.ts` or `src/domain/types.mbt`)

## Workflow

Follow the 6-phase iterative loop. Load references as needed:

- `references/methodology.md` — full definitions and verification criteria
- `references/ts-patterns.md` or `references/mbt-patterns.md` — language-specific type patterns
- `references/state-modeling.md` — state space analysis for gap detection (Phase 0, 3, 5)

### Phase 0: Problem Space Inventory

Gather all available information (specs, existing code, protocol docs, stakeholder input). Produce a tagged list with 4 sections.

**Decomposition heuristic:**
- **Inputs** = nouns/data that enter the system from outside (user input, API requests, file uploads, external events)
- **Outputs** = nouns/data the system produces or exposes (UI views, API responses, stored records, notifications)
- **Transformations** = verbs/processes converting inputs to outputs (validate, create, dispatch, aggregate)
- **Constraints** = adjectives/rules limiting valid states (cardinality, allowed values, ordering, uniqueness, timing)

An item may appear in multiple sections if it serves multiple roles. Prefer the most specific section.

```markdown
## Inputs
- [KNOWN] HTTP request with JSON body containing order items
- [HYPOTHESIS] Authentication token in Authorization header
- [UNKNOWN] Rate limiting rules

## Outputs
- [KNOWN] Order confirmation with order ID
- [HYPOTHESIS] Email notification to customer

## Transformations
- [KNOWN] Validate order items → check stock availability → create order
- [UNKNOWN] Payment processing flow

## Constraints
- [KNOWN] Order must have at least 1 item
- [HYPOTHESIS] Maximum 100 items per order
```

**Tag definitions:**

| Tag | Meaning | Phase 1 treatment |
|---|---|---|
| `KNOWN` | Confirmed by spec or information source | → concrete type |
| `HYPOTHESIS` | Reasonable inference without confirmation | → concrete type + `// HYPOTHESIS` comment |
| `UNKNOWN` | No information exists | → placeholder type |

**State store analysis** (load `references/state-modeling.md` for details):

For items involving state (status fields, lifecycle phases, connection states), also record:
- **Store** — where the state lives (DB, localStorage, memory, URL, etc.)
- **Lifecycle** — when initialized, when destroyed
- **Sync risk** — does this state need to stay in sync with another store?

```markdown
- [KNOWN] Agent connection state (online / offline / busy)
  - Store: in-memory (server process)
  - Lifecycle: agent registration → agent removal
  - Sync risk: must sync with actual agent process health
```

**Verify:** Every item has a tag. If UNKNOWN count is 0, suspect oversight. If KNOWN count is < 30% of total, the inventory is likely incomplete.

**Output:** Present the tagged list to the user for review before proceeding.

### Phase 1: Initial Type Definitions

Convert tagged items to types. Write output to the agreed target file. Load the language-specific pattern reference first:

- TypeScript → `references/ts-patterns.md`
- MoonBit → `references/mbt-patterns.md`

**Conversion rules (language-agnostic):**

| Problem space structure | Type construction |
|---|---|
| A has B and C | Product type (record/struct) |
| A is B or C | Sum type (discriminated union/enum) |
| A is constrained primitive | Wrapper/newtype + parse function returning `Result` |
| A transforms to B | Function signature `A → Result<B, Error>` |
| A has many B | Collection type (`Array`, `ReadonlyArray`, etc.) |
| A may or may not have B | Sum type preferred over optional field (see patterns ref) |
| A goes through states S1→S2→S3 | Separate type per state + transition functions (see patterns ref) |

**UNKNOWN items → explicit placeholders** (syntax in patterns ref).

**Verify:** Code compiles (`tsc --noEmit` / `moon check`). Record placeholder count.

### Phase 2: Minimal Path Implementation

Select the path with the highest KNOWN ratio. Implement one end-to-end flow from input to output.

**Verify:** At least 1 test passes. Record every type mismatch encountered as `{file, line, description}`.

### Phase 3: Mismatch Detection

Scan the implementation for mismatches. Load `references/state-modeling.md` for formal detection methods.

**Type-level mismatches:**

1. **Type deficit** — Runtime value narrower than type. Search: `String`/`string` variables holding 3-5 fixed values.
2. **Type bloat** — One type used across contexts with different field subsets. Search: optional fields used only in specific contexts.
3. **Branch leak** — Domain branching via `if`/`switch`/`match` instead of sum type. Search: `if (x.status === "...")` or `match x.status { ... }`.
4. **Signature mismatch** — Return type wider than actual domain. Search: functions returning `String`/`string` with narrower actual value domains.

**State-level mismatches** (from state space analysis):

5. **Unreachable variant** — Sum type variant that no code path ever constructs. Indicates dead type definition.
6. **Missing state** — Error/intermediate/timeout state not represented in types. Detectable when δ(q, σ) is undefined for some (state, event) pair.
7. **Information loss** — Different contexts merge into the same type, losing distinction. Detectable when two different states converge to the same type via the same operation (State Smell).
8. **Hidden state** — State reachable only when multiple stores lose sync. Detectable by computing Q₁ × Q₂ cross-product and checking for unhandled combinations.

Record each: `{file:line, category, current, action}`.

**Verify:** All entries have file location and action. Run `bash scripts/measure_metrics.sh <src-dir> <ts|mbt>` and record metrics.

### Phase 4: Type Revision

For each mismatch, apply exactly one operation:

| Operation | Effect |
|---|---|
| **Split** | Break 1 type into 2+. Compiler errors at all usage sites → select correct new type. |
| **Merge** | Combine 2+ types. Type mismatch errors → replace with merged type. |
| **Add constraint** | Add validation to parse function. Callers must handle `Result`. |
| **Make implicit explicit** | Convert comment/if rule into a type. Usage sites error → migrate. |

Procedure: change types → compile → fix errors → repeat until zero → run tests.

**Verify:** Compiles. Tests pass. Placeholder count <= Phase 1. External branch count <= Phase 3.

### Phase 5: Structural Defect Judgment

| Condition | Action |
|---|---|
| Same type in mismatch list 3+ iterations | → Phase 0 (wrong premise) |
| Multiple mismatches share root cause | → Phase 0 (redesign needed) |
| New path increases placeholder count | → Phase 0 (structural gap) |
| Domain concepts and type names diverge | → Phase 0 (wrong decomposition) |
| 3+ hidden states detected across stores | → Phase 0 (store architecture redesign) |
| State Smell repeats across iterations | → Phase 0 (sum type variant design flawed) |
| None of the above | → Phase 2 (next path) |

### Loop Invariants

After every iteration: (1) code compiles, (2) tests pass, (3) placeholder count recorded, (4) external branch count recorded.

### Termination

Complete when: placeholder count = 0, all paths implemented, external branch count = 0, signature lie count = 0. If metrics plateau, record remaining items as technical debt.

## Design Principles

Apply during all type design. Load `references/methodology.md` for violation detection methods and examples.

1. **Make illegal states unrepresentable** — Type value domain = problem space valid value domain.
2. **Parse, don't validate** — External data enters as `unknown`/`String`, exits via `Result`-returning parse function.
3. **State transitions as types** — Each entity state = separate type. Transitions = function signatures.
4. **One type, one context** — If fields are partially used in different contexts, split into per-context types.

## Resources

- `references/methodology.md` — Full methodology: definitions, verification criteria, violation detection
- `references/ts-patterns.md` — TypeScript: foundational types, conversion examples, placeholder syntax
- `references/mbt-patterns.md` — MoonBit: foundational types, conversion examples, placeholder syntax
- `references/state-modeling.md` — State space analysis: 4 anomalies, State Smell, hidden states, lifecycle/sync analysis
- `scripts/measure_metrics.sh` — Automated metrics. Usage: `bash scripts/measure_metrics.sh <source-dir> <ts|mbt>`
