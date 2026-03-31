# Vault Rules Reference

## Frontmatter Fields

| Field | Required | Values | Description |
|---|---|---|---|
| `date` | Yes | `YYYY-MM-DD` | Creation date |
| `categories` | Yes | list of: `knowledge`, `project`, `reading`, `idea`, `daily` | Note classification |
| `tags` | Yes | list of kebab-case strings | Technical/topic tags |
| `source` | Yes | `auto` or `manual` | `auto` = agent-generated, `manual` = human-created |
| `status` | Yes | `draft` or `published` | `draft` = pending human review |

## Permission Matrix

| Location | Agent Read | Agent Write | Agent Modify | Notes |
|---|---|---|---|---|
| `Daily/` | Yes | Yes (append) | No | Append only, don't overwrite |
| Root `*.md` | Yes | Yes (create) | No | Must use `source: auto, status: draft` |
| `Templates/` | Yes | No | No | Managed by Nix |
| `Attachments/` | Yes | No | No | Human only |
| `AGENTS.md` | Yes | No | No | Managed by Nix |

## Naming Conventions

- Daily notes: `YYYY-MM-DD.md` in `Daily/`
- All other notes: `descriptive-slug.md` in vault root
- Slugs: lowercase, hyphens, no spaces
- Tags: kebab-case (e.g., `#nix-flake`, `#typescript-effect`)
- Links: `[[note-name]]` wikilink format

## Draft Lifecycle

```
Agent creates note (source: auto, status: draft)
  → Human reviews
    → Promote: change status to published
    → Edit: modify content, then promote
    → Reject: delete or move to Archives/
```
