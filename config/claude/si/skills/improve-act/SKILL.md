---
name: improve-act
description: Execute improvement proposals from analysis reports — edit CLAUDE.md, create skills, update hooks
user_invocable: true
---

# /improve-act — Execute Improvement Proposals

Read the latest analysis report and execute approved proposals to improve the Claude Code environment.

## Workflow

1. **Load the latest report** from `.si/data/reports/` (most recent by date).
   - If no reports exist, tell the user to run `/improve-analyze` first.

2. **For each proposal in the report**, present:
   - Action type and target file
   - Draft content / diff preview
   - Ask for approval via AskUserQuestion: **Apply** / **Skip** / **Modify**

3. **Execute approved proposals** by action type:

   | Action Type | Target | Method |
   |---|---|---|
   | `project-claudemd` | `CLAUDE.md` (repo root) | Append or edit section |
   | `global-claudemd` | `config/claude/CLAUDE.md.tmpl` | Append or edit section. Note: requires `nixos-rebuild switch` to take effect |
   | `new-skill` | `.si/skills/<name>/SKILL.md` | Create new skill file + symlink in `.omc/skills/` |
   | `workflow-skill` | `.si/skills/<name>/SKILL.md` | Create new skill file + symlink in `.omc/skills/` |
   | `hook-update` | `.si/scripts/` + `.claude/settings.json` | Add detection patterns or new hook scripts |
   | `tool-config` | Various | Apply suggested configuration changes |

4. **Update entry statuses**: For each entry addressed by an executed proposal, update its frontmatter `status` from `open` to `addressed`.

5. **Record the action** in `.si/data/actions/YYYY-MM-DD-action-<index>.md`:

```yaml
---
date: "YYYY-MM-DD"
report: "<report-filename>"
proposal_index: <N>
action_type: <type>
target: "<file-path>"
status: applied | skipped | modified
---
# Action: <description>
## Changes Made
- <list of changes>
## Entries Addressed
- <list of entry filenames whose status was updated>
```

6. **Summary**: After processing all proposals, show:
   - Number of proposals applied / skipped / modified
   - Files changed
   - Reminder about `nixos-rebuild switch` if global CLAUDE.md was modified
   - Reminder to create symlinks if new skills were created

## Guidelines

- Never auto-apply without user confirmation — always ask per-proposal
- When editing CLAUDE.md or templates, preserve existing structure and formatting
- For new skills, follow the SKILL.md format with proper frontmatter (name, description, user_invocable: true)
- When creating symlinks for new skills: `ln -s ../../.si/skills/<name> .omc/skills/<name>`
- If a proposal conflicts with existing content, show both and ask the user to resolve
- Keep action records even for skipped proposals (with `status: skipped`) for audit trail
