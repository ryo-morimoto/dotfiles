---
title: refactor: Simplify shared agent instructions
type: refactor
status: completed
date: 2026-05-13
origin: docs/plans/agents-md-classification.md
---

# refactor: Simplify shared agent instructions

## Summary

Replace `home/agents/_AGENTS.md` with a compact, tool-neutral shared instruction file for Claude Code and
Codex. Keep behavior-critical policies such as intent-first execution, source-first decisions, edit/retry
discipline, and context economy; remove stale role routing, slash-command gates, and tool-specific workaround
text from the always-loaded global context.

## Problem Frame

`home/agents/_AGENTS.md` is injected into both Claude Code and Codex, but it currently mixes cross-project
working agreements with Claude-specific tool names, old compound-engineering routing, repo-specific edit details,
and historical fallback rules. That creates drift risk and wastes context on guidance that is no longer a reliable
source of truth.

## Assumptions

This plan was authored from the existing classification memo and local source reads, without a new synchronous
preference confirmation.

- The rewrite draft in `docs/plans/agents-md-classification.md` is the preferred baseline.
- English is acceptable for the shared global instruction text because the target is cross-agent portability.
- Root `AGENTS.md` remains the source of truth for dotfiles-specific Nix, build, formatting, and maintenance rules.

## Requirements

- R1. Keep `home/agents/_AGENTS.md` short, cross-project, and meaningful to both Claude Code and Codex.
- R2. Preserve behavior-critical policies: intent-first execution, comprehension retention, source-first decisions,
  structured planning responses, context/tool-call economy, edit/retry discipline, review posture, and knowledge
  capture.
- R3. Remove stale or harmful global defaults: Claude/Codex role division, rescue naming notes, token fallback
  routing, hard `/workflows:*` gates, file-count planning gates, hook-specific parallel Bash workaround, and
  compound-engineering subagent trigger tables.
- R4. Keep repo-specific or deterministic enforcement in the correct source of truth: root `AGENTS.md`, tool
  settings, hooks, scripts, CI, or skill metadata.
- R5. Leave `home/agents/claude-code.nix` and `home/agents/codex.nix` wired to the same shared context file unless
  implementation proves the current wiring no longer evaluates.
- R6. Track unresolved adjacent work without expanding this change into a broader documentation migration.

## Scope Boundaries

- Do not change Claude Code or Codex runtime behavior except for the shared context text they receive.
- Do not redesign APM package selection, skill installation, plugin metadata, or MCP definitions.
- Do not solve root `AGENTS.md` and `CLAUDE.md` drift in this plan.
- Do not create or rewrite workflow skills as part of this change.
- Do not move deleted historical notes into a new permanent doc unless the implementation discovers an active
  consumer.

### Deferred to Follow-Up Work

- Root `AGENTS.md` / `CLAUDE.md` drift: decide whether to import, symlink, generate, or continue separate files.
- Knowledge workflow cleanup: decide whether Obsidian-specific policy should remain global or move fully into a
  knowledge skill.
- APM `skill-creator` directory naming: decide separately whether display name and installed directory name need
  normalization.
- Root `AGENTS.md` size reduction: split long repo references only after the global `_AGENTS.md` rewrite lands.

## Context & Research

### Relevant Code and Patterns

- `docs/plans/agents-md-classification.md`: source memo with item-level classification, rewrite draft, deletion
  criteria, and validation criteria.
- `home/agents/_AGENTS.md`: current shared instruction text to replace.
- `home/agents/claude-code.nix`: injects `builtins.readFile ./_AGENTS.md` into `programs.claude-code.context`.
- `home/agents/codex.nix`: injects `builtins.readFile ./_AGENTS.md` into `programs.codex.context`.
- `AGENTS.md`: dotfiles-specific source of truth for Nix formatting, flake checks, repo structure, and preference
  log.

### External References

The external research is already summarized in the origin memo and does not need to be re-run for this implementation.
The key planning takeaway is that always-loaded agent memory should be short, scoped, and focused on facts or behavior
that must apply every session.

## Key Technical Decisions

- Replace rather than incrementally edit `home/agents/_AGENTS.md`: the target text is shorter and the current file has
  stale sections throughout, so a focused replacement is easier to review than many local edits.
- Keep one shared file for Claude Code and Codex: the problem is tool-specific content inside the shared file, not the
  shared-file model itself.
- Delete stale operational history instead of moving it by default: the classification memo already preserves the
  reasoning, while permanent docs should only carry currently useful operating knowledge.
- Generalize tool-specific instructions: preserve the intent behind source reads, anchored edits, and structured
  questions without naming harness-specific tools such as `Read`, `Edit`, or `AskUserQuestion`.
- Keep Obsidian knowledge policy in a generalized form for now: "record non-obvious reusable learnings" is a
  cross-project habit, while command names and detailed workflow stay outside global context.

## Open Questions

### Resolved During Planning

- Should deletion mean "unimportant"? No. In this plan, deletion means "not appropriate for always-loaded shared
  context"; historical rationale remains in `docs/plans/agents-md-classification.md`.
- Should `home/agents/claude-code.nix` and `home/agents/codex.nix` split contexts? No. The existing shared reference is
  retained unless evaluation shows it is broken.

### Deferred to Implementation

- Exact final wording of `home/agents/_AGENTS.md`: start from the origin rewrite draft, but allow small edits for
  clarity while preserving R1-R3.
- Whether root `AGENTS.md` needs a preference-log update: inspect during implementation and edit only if the current
  preference log does not already capture the shared-instruction direction.

## Implementation Units

### U1. Replace the shared global instruction text

**Goal:** Convert `home/agents/_AGENTS.md` into a compact, tool-neutral instruction file based on the rewrite draft in
the origin memo.

**Requirements:** R1, R2, R3

**Dependencies:** None

**Files:**
- Modify: `home/agents/_AGENTS.md`
- Test: none

**Approach:**
- Replace the current long Japanese instruction file with the shorter shared-policy structure from
  `docs/plans/agents-md-classification.md`.
- Keep these sections or equivalent concepts: intent-first work, human understanding, source-first decisions, defaults,
  tools/context, editing/retry discipline, reviews, and knowledge.
- Remove references to old role division, rescue naming, fixed workflow sequence, `/workflows:*`, hook-blocked Bash
  workaround, hard file-count gates, and compound-engineering subagent routing.

**Patterns to follow:**
- `docs/plans/agents-md-classification.md` rewrite draft.
- Existing `home/agents/claude-code.nix` and `home/agents/codex.nix` shared context pattern.

**Test scenarios:**
- Content scan: `home/agents/_AGENTS.md` no longer contains `codex:rescue`, `codex:codex-rescue`,
  `/workflows:plan`, `/workflows:compound`, `Subagent トリガー`, `hook-blocked`, or "3 ファイル以上".
- Content scan: `home/agents/_AGENTS.md` still contains policy coverage for source-first decisions, comprehension
  retention, edit/retry discipline, MCP or tool-output economy, review findings, and knowledge capture.
- Review scenario: a reader can understand the shared defaults without knowing Claude Code-specific tool names.

**Verification:**
- The file is materially shorter than the current version and contains only cross-project behavioral guidance.

### U2. Verify placement of removed or migrated rules

**Goal:** Ensure removed `_AGENTS.md` content is either intentionally deleted or already represented in the appropriate
source of truth.

**Requirements:** R3, R4, R6

**Dependencies:** U1

**Files:**
- Inspect: `AGENTS.md`
- Inspect: `docs/plans/agents-md-classification.md`
- Modify: `AGENTS.md` only if the preference log lacks the finalized shared-instruction policy
- Test: none

**Approach:**
- Treat the item-level migration table in `docs/plans/agents-md-classification.md` as the authoritative deletion and
  migration rationale.
- Confirm root `AGENTS.md` already covers dotfiles-specific rules such as Nix formatting, flake checks, source-first
  repo behavior, and preference-log maintenance.
- Do not create new docs for R1-R3, W2-W3, or T2-T3 unless an active consumer is found.

**Test scenarios:**
- Documentation scenario: every removed class from the origin memo has one of these outcomes: retained in generalized
  form, covered by root `AGENTS.md` or tool settings, delegated to skill metadata, or explicitly deleted with rationale.
- Preference-log scenario: if `AGENTS.md` is edited, the new entry is concise and does not duplicate the full rewrite.

**Verification:**
- No deleted item has an unclear destination or reason.

### U3. Confirm Claude Code and Codex context wiring

**Goal:** Verify both agent integrations still consume the rewritten shared file through the existing Nix module wiring.

**Requirements:** R1, R5

**Dependencies:** U1

**Files:**
- Inspect: `home/agents/claude-code.nix`
- Inspect: `home/agents/codex.nix`
- Test: none

**Approach:**
- Keep `builtins.readFile ./_AGENTS.md` in both modules.
- Avoid changing `.nix` files if the current context injection continues to evaluate.
- If implementation touches `.nix` files anyway, run `nixfmt` on changed Nix files and evaluate the relevant Home
  Manager attributes.

**Test scenarios:**
- Integration scenario: Claude Code context and Codex context both resolve to the rewritten shared text.
- Regression scenario: no new separate Claude-only or Codex-only global instruction file is introduced.

**Verification:**
- The context source path remains shared between Claude Code and Codex.

### U4. Preserve follow-up tracking without expanding scope

**Goal:** Keep adjacent issues visible while preventing this refactor from becoming a broad documentation redesign.

**Requirements:** R6

**Dependencies:** U1, U2

**Files:**
- Modify: `docs/plans/agents-md-classification.md` only if implementation uncovers a missing decision
- Test: none

**Approach:**
- Leave the origin memo as the long-form rationale.
- If implementation changes a decision from the memo, update the memo's migration/deletion table instead of burying the
  rationale in commit text.
- Keep deferred work as follow-up bullets rather than implementing it in this change.

**Test scenarios:**
- Scope scenario: the final diff does not include unrelated APM, plugin, MCP, or root documentation restructuring.
- Traceability scenario: the final `_AGENTS.md` wording can be traced back to the origin memo's keep/rewrite/delete
  decisions.

**Verification:**
- This plan and the origin memo remain sufficient context for a future root `AGENTS.md` / `CLAUDE.md` drift pass.

## System-Wide Impact

- **Interaction graph:** Claude Code and Codex both receive the changed global context through Home Manager-managed
  module configuration.
- **Error propagation:** No runtime code path changes are expected; the risk is prompt/instruction behavior drift, not
  process failure.
- **State lifecycle risks:** Low. The main risk is partial migration, where stale tool-specific rules remain in global
  context while new generalized text is added.
- **API surface parity:** Not applicable; no public API, schema, or CLI contract changes.
- **Integration coverage:** Nix evaluation of the relevant Home Manager user configuration is enough if `.nix` files are
  touched. For markdown-only changes, content review is the primary verification.
- **Unchanged invariants:** `home/agents/claude-code.nix` and `home/agents/codex.nix` should continue to read the same
  shared file.

## Risks & Dependencies

| Risk | Mitigation |
| --- | --- |
| Over-pruning removes useful guardrails | Validate R2 coverage with explicit content scans after the rewrite. |
| Stale terms survive in the rewritten file | Search for known removed strings from U1 before finishing. |
| Deleted operational notes are needed later | Keep rationale in `docs/plans/agents-md-classification.md`; recreate active docs only when there is a consumer. |
| Root `AGENTS.md` and `CLAUDE.md` drift remains | Treat it as deferred follow-up, not a blocker for the shared global context cleanup. |
| `.nix` changes accidentally enter scope | Prefer no Nix edits; if touched, run `nixfmt` and relevant Nix evaluation. |

## Verification Plan

- Content review `home/agents/_AGENTS.md` against R1-R3.
- Search for removed stale terms listed in U1.
- Confirm `home/agents/claude-code.nix` and `home/agents/codex.nix` still reference `./_AGENTS.md`.
- If `.nix` files are modified, run `nixfmt` on changed Nix files and evaluate the relevant Home Manager configuration.
- If only Markdown files are modified, no `nixfmt` or `nix flake check` is required by this plan.

## Sources & References

- `docs/plans/agents-md-classification.md`
- `home/agents/_AGENTS.md`
- `home/agents/claude-code.nix`
- `home/agents/codex.nix`
- `AGENTS.md`
