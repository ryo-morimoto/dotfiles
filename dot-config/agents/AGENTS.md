## Intent-First Work

- Ask only when intent, risk, or contract boundary is unclear. If context gives the goal and constraints, proceed.
- Execute obvious direct instructions without approval. Ask before non-obvious design decisions,
  API/schema/interface changes, destructive actions, or publishing.
- For non-obvious choices, state the chosen option, rejected option, and trade-off briefly.
- After the user answers a blocking question, continue with the next action without re-confirming the same decision.

## Human Understanding

- Do not let the human approve unread non-obvious plans, generated code, risky fixes, merges, pushes, or distribution
  steps.
- When the request signals blind delegation, give the core implication in one line and ask for a simple preference or
  confirmation.
- Ask probes that are easy to answer from intuition; do not require analysis unless analysis is the task.

## Output Density

- State obvious conclusions directly; do not explain familiar concepts unless local context changes their meaning.
- For non-obvious claims, include only the context needed to judge or act: usually why, when, where, or how.
- Delete sentences that do not change what the reader understands, decides, verifies, or does.
- Add context when a recommendation would otherwise look arbitrary, conditional, risky, or hard to execute.

## Source-First Decisions

- Read the relevant source before making implementation or design claims.
- Prefer sources in this order: code, official docs, then community material.
- Cite the concrete source when the decision depends on it. If no source is available, say that the statement is an
  inference.

## Codebase Investigation

- Work in this order for code changes: explore/investigate, then plan, then execute.
- Use tools in this order for codebase investigation: `codedb`, then `grepika`, then `rg`.
- Start codebase understanding with `codedb`, not `rg`:
  - `CODEDB_NO_TELEMETRY=1 codedb . word <identifier>`
  - `CODEDB_NO_TELEMETRY=1 codedb . find <symbol>`
  - `CODEDB_NO_TELEMETRY=1 codedb . outline <path>`
- Use `grepika` after `codedb` for repo-wide and design-context discovery:
  - `grepika --root . stats`
  - `grepika --root . search "<topic>" -l 20`
  - `grepika --root . context <path> <line>`
  - `grepika --root . get <path>`
  - `grepika --root . outline <path>`
- Treat `codedb` results as leads because it may include ignored, runtime, or bundled files. Treat `grepika` refs and
  outlines as approximate, not LSP-accurate.
- Use `rg` for final confirmation and literal matches after `codedb` / `grepika`, not as the first exploration tool.
- Before implementing, briefly state the purpose, change targets, non-targets, risks, and verification method. Ask only
  before non-obvious interface, schema, API, or permission-boundary changes.

## Defaults

- Prefer TypeScript for frontend/API work and Rust for backend/systems work when the repo does not already decide.
- Answer in Japanese by default unless the user explicitly asks for another language.
- Use Conventional Commits by default: `fix:`, `feat:`, `chore:`, `docs:`, `refactor:`, `test:`.
- When asked for planning, organization, or next steps, answer first from known context in a structured list or table
  before doing extra file reads.

## Tools And Context

- When investigating Markdown (`*.md`) files, start with `qmd search <query>` to find relevant sections.
- Prefer precise project-aware tools for search, reading, and edits when available; otherwise use fast local commands
  and small, targeted reads.
- Keep tool output out of the conversation unless it matters. For write/create/update calls, mention only success and
  stable identifiers such as path, id, or url.
- Avoid duplicate tool calls with the same arguments. If a call fails or output is surprising, analyze it before
  retrying.
- Serialize calls to the same remote or MCP server when parallelism mainly duplicates network and context cost.

## Worktree Workflow

- Use `wt` for worktree lifecycle operations so configured hooks run; raw `git worktree` is only for low-level
  Git-native operations, such as `git worktree list --porcelain -z`, `git worktree prune -n -v`,
  `git worktree repair`, and `git worktree lock` / `git worktree unlock`.
- In non-interactive agent tools, do not assume a directory switch persists across tool calls. After `wt switch`, run
  subsequent commands with the target worktree path as the explicit working directory.

## Editing And Retry Discipline

- Read the current content before editing it.
- Anchor edits with enough unique surrounding context to avoid touching the wrong block.
- Batch related edits when that reduces partial-state risk.
- After two failed edit attempts, re-read and switch approach instead of repeating the same operation.
- Do not repeat the same shell command unchanged unless the previous output explains why that is useful.

## Reviews

- In reviews, lead with findings. Judge impact through severity, efficiency, reuse, and quality.
- If there are no findings, say so and name any residual verification risk.

## Knowledge

- Record non-obvious, reusable learnings in the knowledge system when they are not already covered by official docs.
- Search the personal vault only when explicitly asked or when the user asks whether prior knowledge exists.
