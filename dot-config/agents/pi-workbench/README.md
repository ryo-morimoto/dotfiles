# Pi Agent Workbench

This directory stores reviewed notes, config examples, and verification checklists for a Pi-based agent workbench.
It is intentionally documentation-first: do not add a local workbench runtime until an existing project fails a written
contract and the failure cannot be fixed upstream quickly.

## Scope

- Reuse `acp-adapter` for Zed ACP to Pi.
- Reuse Pi packages and MCP servers for runtime capabilities.
- Keep durable memory, code mode, permissions, session search, and package management in existing projects first.
- Store only examples, evaluation receipts, compatibility checks, and thin adapters here.

## Non-Goals

- No custom ACP server.
- No custom agent framework.
- No custom package manager.
- No custom permission language.
- No custom memory database or vector store.
- No custom code-mode sandbox.
- No custom graph engine or viewer.
- No provider router in the MVP.

## Directory Map

- `reuse-inventory.md`: candidate map by capability.
- `decisions.md`: current choices and explicit deferrals.
- `candidate-evaluations/`: one evaluation per candidate.
- `config.examples/`: non-live examples for Pi, Zed, MCP, APM, Code Mode, and local models.
- `verification/`: acceptance matrix and smoke checklist.

## Operating Rule

Use hooks for automatic capture, restore, reminders, and guardrails. Use tools for intentional search, checkpoint,
correction, and recovery. Keep the system prompt small.

