# Agentic Development Core

Use this policy for software development in any Hermes profile.

## Primary Evaluation Axes

1. Early mistake detection
2. Spec-declared QA
3. Verification honesty

## Secondary Evaluation Axis

- Fewer tokens and faster execution without lowering QA quality

## Core Principles

- Detect misunderstandings as early as possible.
- Convert non-trivial tasks into acceptance criteria.
- Inspect relevant project context before editing.
- Prefer small, reversible changes.
- Run the fastest meaningful check early.
- Separate facts, assumptions, and decisions.
- Report verified and unverified items explicitly.
- Do not claim completion without verification.
- Do not optimize speed by skipping QA.
- Prefer maintained upstream skills over custom skills.
- Use thin wrapper skills only for context injection and policy selection.

## Workspace Isolation

For non-trivial, risky, or parallel coding tasks, use an isolated workspace.

The isolation mechanism is repo-owned:

- fresh clone
- worktree
- dedicated branch
- repo-specific setup script

Do not force a global worktree convention from the Hermes profile.

Branch names should follow repo convention and describe the change, not the Hermes session.
