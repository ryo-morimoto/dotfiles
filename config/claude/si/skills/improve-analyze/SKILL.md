---
name: improve-analyze
description: Analyze self-improvement log entries, score patterns, cluster insights, and generate an actionable report
user_invocable: true
---

# /improve-analyze — Entry Analysis & Report Generation

Analyze all accumulated entries in `.si/data/entries/`, identify patterns, and generate an actionable improvement report.

## Workflow

1. **Read all entries** from `.si/data/entries/*.md`
   - Parse YAML frontmatter for: date, category, tags, impact, status, source
   - Skip entries with `status: addressed`

2. **Aggregate by tag and category**
   - Count frequency of each tag across entries
   - Count frequency of each category
   - Track which files appear most in `related_files`

3. **Score each cluster** using:
   ```
   score = frequency × impact_weight × recency_bonus
   ```
   - `impact_weight`: low=1, medium=2, high=4
   - `recency_bonus`: 1.5 if any entry in the cluster is within the last 7 days, 1.0 otherwise

4. **Cluster entries** by shared tags (2+ common tags form a cluster)

5. **Map clusters to action types**:

   | Pattern | Action Type |
   |---|---|
   | Same file with repeated errors | `project-claudemd` — Add warning/note to project CLAUDE.md |
   | Same category gotcha 3+ times | `global-claudemd` — Add rule to global CLAUDE.md template |
   | Successful patterns repeating | `new-skill` — Extract as a reusable skill |
   | Retry patterns concentrated | `workflow-skill` — Create workflow automation skill |
   | High error rate in session summaries | `tool-config` — Suggest tool/config changes |

6. **Generate report** at `.si/data/reports/YYYY-MM-DD-report.md`:

```yaml
---
date: "YYYY-MM-DD"
entries_analyzed: <count>
clusters_found: <count>
proposals: <count>
---
# Improvement Analysis Report

## Summary
- Entries analyzed: X (Y new since last report)
- Open entries: X
- Top categories: ...
- Top tags: ...

## Clusters

### Cluster 1: <descriptive-name>
- **Score**: X.X
- **Entries**: <list of entry filenames>
- **Common tags**: [tag1, tag2]
- **Pattern**: <description of what's recurring>

#### Proposal
- **Action type**: project-claudemd | global-claudemd | new-skill | workflow-skill | tool-config
- **Target**: <file to modify or create>
- **Description**: <what to add/change>
- **Draft content**:
  ```
  <actual content to add>
  ```

### Cluster 2: ...
```

7. **Present summary** to the user showing:
   - Number of entries analyzed
   - Top 3 clusters by score
   - Recommended actions
   - Prompt to run `/improve-act` to execute proposals

## Guidelines

- Always read ALL entries, not just recent ones (but weight recent ones higher)
- Be specific in proposals — include draft content that can be directly applied
- For `project-claudemd` proposals, check the current CLAUDE.md first to avoid duplicates
- For `global-claudemd` proposals, check `config/claude/CLAUDE.md.tmpl` first
- Group related small issues into a single proposal when they share a root cause
- If there are fewer than 3 entries, still generate a report but note that more data would improve analysis
