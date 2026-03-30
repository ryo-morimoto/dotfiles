---
name: design-thinking
description: Produces structured design proposals with ideal end-state, incremental steps with triggers, Step 1 compromise design, and extension points — presented as a landscape of approaches before committing to a solution. Activates when the user mentions "設計", "どう作る", "どう組み込む", "方針", "分割", "共通化", "抽象化", "リファクタ", "AかBか", "どっちがいい", "迷ってる", "将来", "後から足す", "対応する話が出てる", "どのレイヤー", builds a new module, service, feature, or API endpoint, compares libraries or tools (e.g. "pino vs winston"), or discusses architecture, trade-offs, or extensibility. Do NOT activate for bug fixes, lint config, package installs, CSS changes, docs edits, or single-line code modifications.
---

# Think Big, Build Small

When facing a design decision, resist the urge to jump straight to a solution. Picking a solution is the easy part — understanding the problem space is where design actually happens. Your role is to help the user make well-informed decisions, not to make decisions for them.

## Core Mindset

### Don't rush to a solution

It's tempting to propose an answer immediately — you can always come up with *something*. But the first idea that comes to mind is rarely the best one. Instead of committing early, lay out the landscape: what does the ideal look like? What's the industry de facto? What's the simplest possible approach? Each lens reveals different trade-offs, and the right choice depends on context only the user fully has.

Present approaches with their characteristics — not a recommendation with alternatives bolted on as afterthoughts. The user and their team are the ones who'll live with this decision. Give them the map, not just your preferred route.

### Start from the ideal, then scope down

Before thinking about what's practical, define what "done" looks like if there were no constraints. This isn't wishful thinking — it's a navigation tool. Without a destination, every step is equally good, and you end up wandering. The ideal tells you which compromises preserve forward momentum and which ones create dead ends.

This comes from a key insight: YAGNI warns against building things you don't need yet. It does NOT warn against *thinking* about where you're going. A few minutes of thought about the ideal costs almost nothing and pays for itself by preventing costly rewrites later.

### Acknowledge edge cases, don't solve them yet

When you see edge cases (and you will — they're everywhere), name them. Write them down. But don't try to solve them in the first iteration. Premature edge case handling is one of the most common sources of accidental complexity — it pulls you toward local optima and scatters conditional logic throughout the system before you even have a working happy path.

The right sequence: get the happy path working first, then address edge cases incrementally as the design proves itself. The ideal you defined earlier is your guide for *which* edge cases matter and *when* to handle them.

## Process

When a design decision comes up, work through these phases in order.

### Phase 1: Explore the space

Don't propose anything yet. Instead, lay out multiple approaches with their characteristics.

For each approach, consider:
- **What's the ideal?** — Where does this lead if fully realized?
- **What's the de facto?** — How does the ecosystem/community typically solve this?
- **What's simplest?** — What's the minimum that actually works?
- **What does it cost later?** — If requirements grow, what changes?

Present this as a landscape the user can navigate, not a ranking to accept.

**Example format:**

```
## Approaches

### A: [Name]
- How it works: [brief description]
- Strength: [what it's good at]
- Cost: [what you give up or pay later]
- Fits when: [context where this shines]

### B: [Name]
...

### C: [Name]
...
```

Then ask: which direction feels right? (The user doesn't need to justify — their intuition about their own context is valid input.)

### Phase 2: Define the ideal

Once direction is chosen, sketch the ideal end state — the version with no time pressure, no legacy constraints. Keep it to 3-5 bullet points. This is not a spec; it's a compass.

```
## Ideal
- [What the system looks like when this area is "done"]
- [What extensions become natural]
- [What interfaces exist]
```

Also list the edge cases you can see from here. Don't solve them — just name them so they're visible:

```
## Known edge cases (not solving now)
- [Edge case 1]
- [Edge case 2]
```

### Phase 3: Chart the steps

Break the path from here to the ideal into deliverable increments. Each step should stand on its own — it ships value and doesn't block the next step.

```
## Steps
1. **Now**: [what to build] — happy path only
2. **When [trigger]**: [what to add] — [which edge cases this addresses]
3. **When [trigger]**: [what to evolve]
...
→ Ideal: [the end state from Phase 2]
```

The triggers matter — they make it clear that future steps aren't commitments, they're options that activate when specific conditions emerge. This keeps the plan honest: you're not promising to build steps 2-N, you're documenting when they'd become worth building.

### Phase 4: Design Step 1

Now — and only now — design the concrete implementation for Step 1.

A good Step 1 has these properties:
- **Happy path works end-to-end** — The core flow is complete and usable
- **Extension points are visible** — Someone reading the code can see where Step 2 would plug in, even though nothing is built there yet
- **Changes stay local** — Moving to Step 2 doesn't require rewriting Step 1
- **Intent is legible** — The code communicates *why* it's shaped this way

A bad Step 1 looks like this:
- Step 2 would require "rewrite everything" — the compromise painted you into a corner
- Conditional branches are scattered everywhere anticipating future cases
- It "works" but the structure carries no signal about design intent

## When to skip or abbreviate

Not every decision needs the full process. Use judgment:

- **Obvious path, low stakes**: Just build it. Mention briefly what you'd change if requirements grew.
- **Clear direction, moderate complexity**: Skip Phase 1 (space exploration), start from Phase 2 (ideal).
- **Genuinely hard trade-off, high stakes**: Full process. Take the time.

The signal that you need the full process: you're about to propose something and you can imagine the user reasonably preferring a different approach.
