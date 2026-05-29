# Engram Evaluation

Candidate: `Gentleman-Programming/engram`
Date checked: 2026-05-29
Source checked: GitHub HEAD `6bfe33d6a5e69e85b685bfc1b4fab5b5e38c71e4`
Registry check: source build reports `engram v1.16.0`; npm `engram@0.0.1` is not the useful install path.

## Contract

- Memory is local and inspectable.
- Project memory is separated from user/global memory.
- Hook-based passive capture works without relying on the agent remembering tools.
- Agent-visible tools support current project, context, prompt save, passive capture, and session lifecycle.
- Redaction happens before storage.
- Unverified reflections do not become permanent global memory automatically.

## Install Command To Try

```sh
engram setup pi
```

Use a disposable Pi profile while evaluating.

## Minimal Config To Try

Enable Engram lifecycle capture for session start, user prompt, post response, compaction recovery, and session end.
Keep permanent memory promotion gated.

## Smoke Commands

```text
mem_current_project()
mem_context("recent project decisions")
mem_save_prompt("test prompt")
mem_capture_passive("test passive capture")
mem_session_summary()
mem_session_end()
```

## Observed Behavior

Source smoke passed: `go test ./...`, `go build ./cmd/engram`, and `engram --help` all succeeded from a shallow clone.
The built binary reports `engram v1.16.0` and help lists `setup [agent]`, including Pi setup, plus `mcp --tools=agent`.

Pi setup and MCP `mem_*` tool calls were not run because they need a live Pi/MCP client profile.

Receipt: `verification/receipts/2026-05-29-local-smoke.md`.

## Disposition

Adopt first for durable memory. Do not enable Magic Context as a second automatic writer until duplicate/conflict behavior
is checked.

## Local Adapter Justified?

No.
