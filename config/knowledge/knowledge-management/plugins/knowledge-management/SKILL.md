---
name: knowledge-management
description: >-
  Manage knowledge in the Obsidian vault at ~/obsidian. Use when the user wants to:
  (1) RECORD a learning — "これ記録して", "メモしておいて", "ナレッジに残す", "TILとして書いて", "知見として保存", "save this as knowledge", "log this learning", "write this down";
  (2) SEARCH past knowledge — "前にやったはず", "以前ハマった", "知見ある?", "vault検索", "ナレッジ検索", "search vault", "check if we solved this before";
  (3) REVIEW drafts — "ドラフト確認", "下書きレビュー", "review drafts";
  (4) USE Obsidian CLI — "obsidian", "vault", "ノート検索", "タグ一覧".
  Also activates on: "ナレッジ", "メモ", "知見", "TIL", "振り返り", "gotcha", "ハマり", "best practice", "pitfall", "deep dive", "設計判断", "design decision".
---

# Knowledge Management

Obsidian vault at `~/obsidian/`. Flat structure — all notes in root, classification via frontmatter.

## Usage

```
/knowledge-management <learning>        # Record a learning
/knowledge-management search <query>    # Search past knowledge
/knowledge-management review            # Review draft notes
```

## Capture Flow

When the user wants to record a learning (or you detect one worth saving):

1. Extract the core insight: **WHEN** [condition] **THEN** [what happens] **BECAUSE** [root cause]
2. Pick a slug: `{descriptive-slug}.md`
3. Write to `~/obsidian/{slug}.md` with frontmatter:

```yaml
---
date: "YYYY-MM-DD"
categories: [knowledge]
tags: [kebab-case-tags]
source: manual
status: published
---
```

4. Add `[[wikilinks]]` to related notes if any exist
5. Confirm to user: note name + tags + one-line summary

### What to Record

Only knowledge that's hard to reach from docs alone:

| Kind | Tags |
|---|---|
| Undocumented behavior, surprising system interactions | `gotcha`, `undocumented` |
| Library pitfalls (edge cases, version incompatibilities) | `pitfall`, `library-specific` |
| Deep-dive findings, root causes | `deep-dive`, `root-cause` |
| Best practice with context (when/why/how) | `best-practice`, `curation` |
| Design decisions (chosen option + rejected alternatives + why) | `decision`, `trade-off` |

### What NOT to Record

- Things easily found in official docs
- Temporary workarounds that will be fixed
- Generic programming knowledge

## Search Flow

1. Use `obsidian search query="<text>"` for full-text search
2. Use `obsidian tags` to browse by tag, `obsidian tag name="<tag>"` for files with a specific tag
3. Use `obsidian backlinks file="<name>"` to find related notes
4. Read top matches and synthesize with `[[note-name]]` citations

## Review Flow

1. Grep for `status: draft` in `~/obsidian/*.md`
2. Present each draft with summary
3. User decides: promote (`status: published`), edit, or delete

## Obsidian CLI Reference

The `obsidian` CLI can be used directly from the terminal for quick vault operations.

### Search & Browse

```bash
obsidian search query="nix flake"              # Full-text search
obsidian search query="pitfall" format=json     # JSON output
obsidian tags                                   # List all tags
obsidian tag name="gotcha"                      # Files with tag
obsidian backlinks file="nix-flake-check"       # What links to this note
obsidian links file="nix-flake-check"           # Outgoing links from note
obsidian recents                                # Recently opened files
```

### Read & Write

```bash
obsidian read file="nix-flake-check"            # Read note content
obsidian create name="my-note" content="..."    # Create note
obsidian append file="my-note" content="..."    # Append to note
obsidian daily                                  # Open today's daily note
```

### Vault Info

```bash
obsidian orphans          # Notes with no incoming links
obsidian deadends         # Notes with no outgoing links
obsidian unresolved       # Broken wikilinks
obsidian outline          # Headings of active file
```

## Write Rules

- Root notes: `source: manual, status: published` when user-initiated
- Agent-initiated notes: `source: auto, status: draft`
- Never modify `status`, `categories`, or `source` on existing notes
- Never delete or overwrite existing notes
- Use `[[wikilinks]]` for cross-references

See [vault rules](references/vault-rules.md) for full specs.
