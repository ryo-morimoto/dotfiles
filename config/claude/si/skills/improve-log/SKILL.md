---
name: improve-log
description: Manually log a learning, gotcha, pattern, mistake, solution, or idea for the self-improvement system
user_invocable: true
---

# /improve-log — Manual Learning Log

Record learnings that hooks can't auto-detect: gotchas, workflow patterns, mistakes, solutions, and ideas.

## Workflow

1. The user provides a description of what they learned or observed.

2. Ask the user to categorize the entry using AskUserQuestion:
   - **Category**: `gotcha` / `pattern` / `mistake` / `solution` / `idea`
   - **Impact**: `low` / `medium` / `high`

3. Infer tags from the content (related files, technologies, keywords).

4. Generate an entry file at `.si/data/entries/YYYY-MM-DD-<slug>.md` with the following format:

```yaml
---
date: "YYYY-MM-DD"
category: <selected-category>
tags: [<inferred-tags>]
impact: <selected-impact>
status: open
source: manual
related_files: [<relevant-files>]
---
# <Title derived from content>
## What Happened
<User's description of the situation>
## Root Cause
<Analysis of why this happened, if applicable>
## Solution / Lesson
<What to do differently, the key takeaway>
```

5. Confirm the entry was written and show the filepath.

## Guidelines

- Keep titles concise but descriptive
- Tags should include technology names (nix, rust, typescript), tool names (nixos-rebuild, cargo), and domain keywords
- For `gotcha` and `mistake` categories, always try to include a Root Cause
- For `solution` and `pattern` categories, focus on the actionable lesson
- Slug should be kebab-case, max 50 chars, derived from the title
- If the user mentions specific files, include them in `related_files`

## Example

User says: "I kept getting hash mismatch errors because I forgot to update flake.lock after editing flake.nix inputs"

→ Category: `gotcha`, Impact: `medium`, Tags: `[nix, flake, hash]`
→ File: `.si/data/entries/2026-02-09-flake-lock-hash-mismatch.md`
