# Pi Workbench Reuse Inventory

Date: 2026-05-29

This inventory tracks existing projects that should be reused before any local
implementation is considered.

| Capability | Candidate | Current ref | State | Local code allowed? |
| --- | --- | --- | --- | --- |
| Zed ACP bridge | `beyond5959/acp-adapter` | `491151b16846682396aca8c31e9285e414e4f3b8` | pending smoke | no; patch/fork upstream first |
| Pi package set | `spences10/my-pi` | `e79ef66eecbd8e222ab4e792d2acf7193539e597` | pending package checks | only config examples |
| Permissions | `MasuRii/pi-permission-system` | `ccebbf4afce3910f3724829b425093e79b006d3d` | pending smoke | only config generation/checks |
| Code context | `justrach/codedb` | `e89e110a695ec64de2d3083b31644011457e55eb` | pending smoke | no graph engine |
| LSP context | `mizchi/lsmcp` | `f2fb91d205c19ffff3be1d6f98bdc130b6e8868f` | pending smoke | only config examples |
| Durable memory | `Gentleman-Programming/engram` | `6bfe33d6a5e69e85b685bfc1b4fab5b5e38c71e4` | pending Pi setup smoke | only bridge docs/prompts |
| Context memory | `cortexkit/magic-context` | `d9728ce483acd5c49fb0cf3a2d5f7284b81e9872` | pending isolated comparison | only config examples |
| Session search | `yoavf/ai-sessions-mcp` | `3bc31862280d7ac1d5097626c4c3bfb4b990fd20` | pending source checks | Pi source adapter only if needed |
| Code Mode | `portofcontext/pctx` | `0b9312decb8673fbb9d8013e4a6495bb5cd7d703` | pending smoke | no sandbox/runtime |
| Subagents | `mjakl/pi-subagent` | `b7f0360a4d16ea76e8caff0279373e2b6b9d4977` | pending smoke | no orchestrator |
| Package distribution | `microsoft/apm` | `ec771e5760a5aa106a60018599273c955e79d7f1` | pending manifest example | no package manager |
| Action DSL research | `mizchi/vibe-lang` | `20d09de2bae8cc77b8c8e42269cc1b6877a045be` | deferred | no MVP dependency |

## Immediate Gaps

- Pi session search is not proven through `ai-sessions-mcp`.
- Engram and Magic Context must not both write automatic memory until duplicate
  write and hook-order behavior is tested.
- `@spences10/pi-lsp` and `lsmcp` overlap; pick by smoke-test coverage, not by
  preference.
- `pctx` is the first Code Mode candidate; `mcpc` remains useful for JSON
  scripting checks but is not yet in the immediate file set.
