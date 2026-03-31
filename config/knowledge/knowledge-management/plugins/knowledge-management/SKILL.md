---
name: knowledge-management
description: Manage knowledge in the Obsidian vault at ~/obsidian. Use when asked to log learnings, search past knowledge, create notes, review drafts, or manage the vault. Also activates on "ナレッジ", "メモ", "vault", "知見", "TIL", "振り返り", "daily", "デイリー". Handles both manual capture and automated session logging.
compatibility: Requires Obsidian CLI (v1.12+) and ~/obsidian vault
---

# Knowledge Management

Manage the Obsidian vault at `~/obsidian/`.

## Vault Structure

```
~/obsidian/
├── AGENTS.md      # Agent rules (read this first)
├── Daily/         # Daily notes (YYYY-MM-DD.md)
├── Templates/     # Note templates
├── Attachments/   # Images, PDFs
└── *.md           # All content notes — flat in root
```

No nested folders. Classification is done via frontmatter, not folder hierarchy.

## Frontmatter Schema

Every note MUST have:

```yaml
---
date: "YYYY-MM-DD"
categories: [knowledge]     # knowledge | project | reading | idea | daily
tags: [kebab-case-tags]     # technical tags
source: auto | manual       # who created it
status: draft | published   # draft = unreviewed by human
---
```

## Agent Write Rules

1. **Daily/** — Free to append. Use `## Session {HH:MM}` heading for each entry.
2. **Root notes** — May create with `source: auto, status: draft`. Human promotes to `published`.
3. **Never** modify `status`, `categories`, or `source` on existing notes.
4. **Never** delete or overwrite existing notes.
5. Use `[[wikilinks]]` for cross-references.

## Workflows

### Capture Knowledge

When the user wants to log a learning or note:

1. Determine category: knowledge, project, reading, or idea
2. Create `{descriptive-slug}.md` in vault root
3. Set `source: manual, status: published` (user-initiated)
4. Add relevant tags and `[[wikilinks]]` to related notes
5. Append a reference to today's Daily note

### Search Vault

When looking up past knowledge:

1. Grep `~/obsidian/` with `glob: "*.md"` for keywords
2. Check frontmatter tags for matches
3. Read top matches (max 5)
4. Synthesize and cite with `[[note-name]]`

### Review Drafts

When the user asks to review agent-created drafts:

1. Grep for `status: draft` in `~/obsidian/*.md`
2. Present each draft with a summary
3. For each: user decides to promote (`status: published`), edit, or delete

### Daily Log (automated via Stop hook)

The `scripts/session-sync.mjs` Stop hook automatically:

1. Appends a session summary to `~/obsidian/Daily/YYYY-MM-DD.md`
2. If notable learnings detected, creates a draft note in vault root

See [vault rules](references/vault-rules.md) for detailed frontmatter and permission specs.
