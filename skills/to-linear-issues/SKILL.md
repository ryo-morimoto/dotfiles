---
name: to-linear-issues
description: Break a plan, spec, or PRD into independently-grabbable Linear issues using tracer-bullet vertical slices. Use when user wants to convert a plan into Linear issues, create implementation tickets in Linear, or break down work into Linear issues.
---

# To Linear Issues

Break a plan into independently-grabbable Linear issues using vertical slices (tracer bullets).

Ported from mattpocock's `to-issues` skill. Uses Linear MCP instead of `gh` CLI.

## Linear MCP routing

Pick the MCP server based on the current working directory:

| Path pattern | MCP server |
|---|---|
| `~/ghq/github.com/ryo-morimoto/*` | `linear-personal` |
| anything else | `linear-work` |

All tool names below are written without the `mcp__linear-{personal,work}__` prefix. Prepend the correct one at call time.

## Process

### 1. Gather context

Work from whatever is already in the conversation context.

If the user passes a Linear issue identifier (e.g. `ENG-123`) or URL as an argument, fetch it with `get_issue` (include related comments via `list_comments` if the conversation will need them).

If the user is starting from a PRD, plan doc, or design note in the conversation, use that directly.

### 2. Identify the target team

Every Linear issue lives on a team. Before drafting slices:

- If the parent issue was fetched, reuse its `team` field.
- Otherwise call `list_teams` and confirm the target team with the user. Do not guess.

Also resolve:

- **Project** — if the work belongs to a Linear project, call `list_projects` (filter by team) and confirm.
- **Labels** — if the team uses category labels (bug/enhancement/etc.), call `list_issue_labels` and decide which to apply per slice.
- **Cycle / milestone** — only if the user mentions scheduling. Otherwise leave blank.

### 3. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Vertical slices are only meaningful once you know what "cuts through all layers" actually means in this repo.

### 4. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

### 5. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)
- **Labels**: category labels you plan to apply (if the team uses them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?
- Is the target team / project / labels correct?

Iterate until the user approves the breakdown.

### 6. Create the Linear issues

For each approved slice, create a Linear issue with `save_issue`. Use the issue body template below.

Create issues in dependency order (blockers first) so you can reference real Linear identifiers (e.g. `ENG-124`) in the "Blocked by" field.

- **Parent**: if the source was a Linear issue, set `parentId` on each child slice so they appear as sub-issues. Do NOT modify or close the parent.
- **Team / project**: set on each issue.
- **Labels**: apply the category labels confirmed in step 2.
- **Status**: leave at the team's default ("Triage" or "Backlog") unless the user has asked for something else.
- **Assignee / priority**: leave blank unless the user specifies.

<issue-template>
## Parent

[ENG-XXX](<Linear URL>) — only if the source was a Linear issue, otherwise omit this section.

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- Blocked by ENG-XXX

Or "None — can start immediately" if no blockers.

</issue-template>

### 7. Verify

After creating all slices:

- Print the list of created identifiers (e.g. `ENG-124`, `ENG-125`, ...) so the user can confirm.
- Call `get_issue` on at least the first and last to confirm parent/blocked-by links look right.
- Do NOT close, reassign, or relabel the parent issue.

## Notes

- Linear uses **identifiers** (`ENG-123`), not numbers. Always reference issues by identifier in comments and descriptions.
- Linear's "Blocked by" is modelled via issue **relations**, not free text. If the user wants the dependency surfaced in Linear's UI, create a `blocks` / `blocked_by` relation in addition to mentioning it in the body. If the MCP server surfaces no relation tool, stick to the text-only body field and note that to the user.
- When passing markdown content to `save_issue`, send real newlines (not `\n`) per the linear-personal / linear-work MCP instructions.
