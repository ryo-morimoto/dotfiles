# Candidate Evaluation: Engram

Source: `https://github.com/Gentleman-Programming/engram`
Current ref: `6bfe33d6a5e69e85b685bfc1b4fab5b5e38c71e4`
Role: durable memory protocol and Pi memory package.

## Install

Tried: not yet.

Command to try:

```sh
engram setup pi
```

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| Pi setup installs first-class Pi integration. | pending | Capture generated package and MCP entries. |
| `mem_current_project` works. | pending | Must separate project memory from global memory. |
| `mem_context` returns relevant local context. | pending | Use a repeated task query. |
| `mem_save_prompt` stores intentional prompt memory. | pending | Use non-sensitive test prompt. |
| `mem_capture_passive` supports passive/candidate capture. | pending | Must not promote unverified memories automatically. |
| Session lifecycle tools work. | pending | Test start, summary, and end. |
| Redaction can happen before storage. | pending | Coordinate with redaction package. |

## Decision

Evaluate first for durable memory. Do not enable alongside Magic Context as an
automatic writer until duplicate-write behavior is tested.
