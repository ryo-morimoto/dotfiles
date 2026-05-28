# Obsidian Vault — Agent Rules

This vault is at ~/obsidian. Agents have read/write access with restrictions below.

## Skill

If the `knowledge-management` skill is loaded, use it for all vault operations.
The skill defines the full workflow for knowledge capture, retrieval, and daily logging.

## Quick Rules (when skill is not available)

1. **Daily/** — Free to read/write. Append to existing day's note, don't create duplicates.
2. **Root notes (*.md)** — May create new notes with `source: auto` and `status: draft`.
3. **Never** modify `status`, `categories`, or `source` on existing notes.
4. **Never** delete or overwrite notes.
5. Use `[[wikilinks]]` for cross-references. Tags use kebab-case.

## Frontmatter Schema

```yaml
---
date: "YYYY-MM-DD"
categories: [knowledge, project, reading, idea, daily]
tags: [kebab-case-tags]
source: auto | manual
status: draft | published
---
```

## Folder Structure

- `Daily/` — Daily notes (YYYY-MM-DD.md)
- `Templates/` — Note templates (do not modify)
- `Attachments/` — Images, PDFs
- Everything else — Flat in root, classified by frontmatter
