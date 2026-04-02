---
name: search
description: >-
  Search and retrieve past knowledge from Obsidian vault before starting work.
  MUST use as a sub-agent when investigating, researching, or exploring a topic.
  Triggers: "調査して", "調べて", "前にやったはず", "以前ハマった", "知見ある?", "vault検索", "ナレッジ検索",
  "search vault", "check if we solved this before", "what do we know about".
  Also activate AUTOMATICALLY before: implementing a library integration, making a design decision,
  debugging a problem that might have been solved before, or applying a best practice.
argument-hint: "<search query>"
---

# Knowledge Search

Search the Obsidian vault at `~/obsidian/` to retrieve past learnings before starting work.

**This skill runs as a sub-agent.** It searches, reads, and returns synthesized findings — then exits.

## When to Search (Auto-trigger)

Search the vault **before** any of these:

- Library/framework integration (pitfalls, gotchas)
- Design decisions (past trade-offs, rejected alternatives)
- Debugging (previously solved problems, root causes)
- Best practice application (curated patterns)
- Any "調査" or "investigate" request

## Search Flow

1. **Keyword search:** `obsidian search:context query="<query>"` — matching lines with file:line context
2. **Tag search:** `obsidian tag name="<relevant-tag>" verbose` — browse by domain tag
3. **Drill down:** `obsidian read file="<name>"` — full content of promising matches
4. **Related notes:** `obsidian backlinks file="<name>"` / `obsidian links file="<name>"` — follow connections
5. **Synthesize:** Return findings with `[[note-name]]` citations

## Output Format

Return a structured summary:

```
## Vault Findings: <query>

### Relevant Notes
- [[note-name]]: one-line summary of relevant insight
- [[note-name]]: one-line summary of relevant insight

### Key Takeaways
- Actionable insight 1
- Actionable insight 2

### No Results
If nothing found, state: "vault に該当する知見なし" — do NOT fabricate results.
```

## CLI Quick Reference

```bash
obsidian search:context query="<text>"     # Full-text search with context (primary)
obsidian search query="<text>"             # File name search
obsidian tags counts                       # All tags overview
obsidian tag name="<tag>" verbose          # Files by tag
obsidian read file="<slug>"                # Read full note
obsidian backlinks file="<slug>"           # Incoming links
obsidian links file="<slug>"               # Outgoing links
```
