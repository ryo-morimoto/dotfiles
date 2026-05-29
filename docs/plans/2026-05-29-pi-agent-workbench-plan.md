# pi-agent workbench reuse-first plan

Date: 2026-05-29
Status: rewritten after GitHub reuse review
Principle: do not build a local agent framework. Configure, compose, and validate existing projects first.

## Decision Summary

The original plan assumed a local `pi-agent-workbench` package would own ACP, session search, memory, policy, Code Mode, provider routing, and graph review. GitHub review invalidates that assumption.

New decision:

- Use `beyond5959/acp-adapter` for Zed ACP to Pi.
- Use selected `spences10/my-pi` packages for Pi-native MCP, LSP, context overflow, telemetry, recall, skills, redaction, and team mode.
- Use `MasuRii/pi-permission-system` before building any policy engine.
- Use Pi package lifecycle/hooks first, tools second. Hook handles automatic capture/recovery; agent-visible tools handle intentional search/checkpoints/corrections.
- Use `Gentleman-Programming/engram` as the first durable memory candidate because `engram setup pi` installs a first-class Pi package and MCP adapter.
- Compare `cortexkit/magic-context` for context compaction, auto recall hints, and cross-session project memory. Do not enable two memory writers until conflict risk is checked.
- Use `yoavf/ai-sessions-mcp` for Codex/Claude/Gemini/opencode session search.
- Use `pctx` first for Code Mode over MCP. Use `mcpc` for shell/JSON MCP composition. Use `ipybox` only when Python/IPython stateful execution is explicitly useful.
- Use `codedb` and `lsmcp` directly as MCP/code-intelligence servers. Do not build a graph engine.
- Use `microsoft/apm` as the package/distribution layer. Do not build an agent package manager.
- Use Pi custom model config and pi-ai providers for local/open-weight models before building a router.
- Keep `vibe-lang` and MoonBit as experiments, not MVP dependencies.

Local code is allowed only for:

- configuration examples
- compatibility tests
- result importers
- thin config/format adapters
- reproducible missing-contract proofs

Local code is not allowed for:

- ACP server
- agent framework
- package manager
- permission language
- memory database
- Code Mode runtime
- graph engine/viewer
- local model router
- subagent orchestrator

## Evidence Reviewed

Primary GitHub sources checked:

| Area | Source | Finding |
| --- | --- | --- |
| ACP | `https://github.com/beyond5959/acp-adapter` | Already bridges Pi `--mode rpc` to ACP. Supports Pi session new/list/load, prompt, cancellation, permission gates, config options, slash commands, and Zed-style standalone config. Gaps: Pi MCP routing and ACP fs write are not fully bridged. |
| Pi package set | `https://github.com/spences10/my-pi` | Provides composable Pi packages: MCP, LSP, context SQLite FTS sidecar, recall, redaction, skills, telemetry, team mode, prompt presets. Requires Node `>=24.15.0`. |
| Permission | `https://github.com/MasuRii/pi-permission-system` | Provides tool filtering, system prompt sanitization, runtime allow/ask/deny, bash pattern control, MCP permissions, skill protection, per-agent overrides, and subagent permission forwarding. |
| Session search | `https://github.com/yoavf/ai-sessions-mcp` | MCP server searches local Claude Code, Codex, Gemini CLI, and opencode sessions using BM25. Does not mention Pi support; likely needs a Pi source adapter or upstream PR. |
| Memory protocol | `https://github.com/Gentleman-Programming/engram` | First-class Pi package via `engram setup pi`. Installs `gentle-engram` and `pi-mcp-adapter`, supports HTTP event capture plus MCP gateway, and exposes compact `mem_*` tools such as `mem_current_project`, `mem_context`, `mem_save_prompt`, `mem_capture_passive`, and session lifecycle tools. |
| Context/memory | `https://github.com/cortexkit/magic-context` | Pi extension exists. Provides background compression, cross-session project memory, dreamer consolidation, sidekick context, SQLite shared across Pi/OpenCode, doctor command, and Pi setup wizard. Strong candidate for context pressure and auto recall hints. |
| Agent-agnostic memory fallback | `https://github.com/syntax-syndicate/engram-agent-memory` | Older/alternate Engram source observed in search. Treat `Gentleman-Programming/engram` as canonical unless local install proves otherwise. |
| Graph memory | `https://github.com/DiaaAj/a-mem-mcp` | Self-evolving Zettelkasten-style graph memory over ChromaDB. Tested mainly with Claude Code. More experimental and heavier. |
| Relationship memory | `https://github.com/memory-graph/memory-graph` | MCP memory server with typed relationship categories. Useful later for memory audits, not MVP. |
| Code Mode | `https://github.com/portofcontext/pctx` | Strong first candidate. Aggregates MCP servers and exposes Code Mode through a Deno sandbox with no filesystem/env/network except configured hosts. |
| MCP CLI composition | `https://github.com/apify/mcpc` | Universal MCP CLI with persistent sessions, OAuth, tasks, JSON output for scripting/code-mode-like workflows. Good for tests and shell composition. |
| Python Code Mode | `https://github.com/gradion-ai/ipybox` | Stateful IPython execution, generated MCP Python APIs, optional OS-level sandbox, approval hooks. Use only for Python-heavy workflows. |
| Cloudflare Agents | `https://github.com/cloudflare/agents` | Official Cloudflare agent SDK includes Code Mode, sandboxed execution, persistent state, callable methods, sub-agents. Reference design and Cloudflare deployment path, not local Pi MVP runtime. |
| Subagents | `https://github.com/mjakl/pi-subagent` | Minimal Pi subagent extension with spawn/fork modes, parallel execution, depth/cycle guards, project agent approval. Good default. |
| Subagents alternative | `https://github.com/tintinweb/pi-subagents` | More featureful Pi subagent extension with Claude Code-like UI and steering. Evaluate after minimal subagent works. |
| Code intelligence | `https://github.com/justrach/codedb` | MCP-native Zig code intelligence: 21 tools, `codedb_context`, dependency graph, snapshots, sensitive file blocking, Codex/Claude/Gemini/Cursor registration. Alpha but directly matches need. |
| LSP MCP | `https://github.com/mizchi/lsmcp` | LSP-backed MCP with project overview, symbol search/details, diagnostics, rename, references, MoonBit preset, Node 22+ requirement. |
| Package manager | `https://github.com/microsoft/apm` | Mature agent package manager with `apm.yml`, lockfile, MCP install, plugin export, audit/policy. Use this. |
| vibe-lang | `https://github.com/mizchi/vibe-lang` | Has effects/type checker/WASM/component work and graph/LSIF experiments. Useful research direction, not MVP runtime. |

## Architecture

```text
Zed
  -> acp-adapter --adapter pi
    -> pi / my-pi
      -> selected Pi packages
           - @spences10/pi-mcp
           - @spences10/pi-lsp or lsmcp
           - @spences10/pi-context
           - @spences10/pi-recall
           - @spences10/pi-telemetry
           - @spences10/pi-redact
           - @spences10/pi-skills
           - @mjakl/pi-subagent or @spences10/pi-team-mode
      -> MCP servers / tools
           - codedb
           - lsmcp
           - pctx
           - engram
           - magic-context
           - ai-sessions-mcp
           - chaosbringer / vlmkit / flaker / actrun / similarity
      -> config/distribution
           - APM
           - project .pi/
           - dotfiles examples
      -> optional future experiments
           - vibe-lang action DSL
           - MoonBit deterministic kernels
```

## Repository Layout

This repo stores evaluation results, config examples, and reproducible checks. It does not start with a local workbench implementation.

```text
docs/plans/
  2026-05-29-pi-agent-workbench-plan.md

dot-config/agents/pi-workbench/
  README.md
  reuse-inventory.md
  decisions.md
  candidate-evaluations/
    acp-adapter.md
    my-pi.md
    pi-permission-system.md
    subagents.md
    magic-context.md
    ai-sessions-mcp.md
    pctx.md
    mcpc.md
    codedb.md
    lsmcp.md
    apm.md
    local-models.md
    vibe-moonbit.md
  config.examples/
    zed/
    pi/
    apm/
    mcp/
    magic-context/
    codedb/
    lsmcp/
    pctx/
    models/
  verification/
    smoke-checklist.md
    acceptance-matrix.md
```

Only create `tools/pi-workbench-adapters/` if a checked candidate fails a written contract:

```text
tools/pi-workbench-adapters/
  README.md
  src/
    importers/
    config-translators/
    compatibility-tests/
  test/
```

Allowed there:

- Pi session source adapter for `ai-sessions-mcp`
- config translator between APM/Pi/Zed if needed
- receipt/log importer if existing telemetry cannot be queried
- repro for upstream bugs

Disallowed there:

- custom ACP server
- custom memory DB
- custom Code Mode runtime
- custom graph engine
- custom permission system
- custom provider router

## Phase 0: Install Nothing, Validate Contracts

Goal: avoid committing to local implementation before proving existing tools fail.

Create:

- `dot-config/agents/pi-workbench/reuse-inventory.md`
- `dot-config/agents/pi-workbench/decisions.md`
- one `candidate-evaluations/*.md` per candidate

Each evaluation must record:

- version / commit / release
- install command tried
- minimal config tried
- smoke command
- observed behavior
- contract pass/fail
- reason for rejection if rejected
- upstream issue/PR path if a small fix would solve it
- whether local adapter is justified

Exit criteria:

- No local source directory exists yet.
- Every MVP capability maps to an existing candidate or a written gap.

## Phase 1: Zed ACP to Pi

Adopt by default:

- `beyond5959/acp-adapter`

Test:

```sh
acp-adapter --adapter pi --pi-provider openai-codex --pi-model <model>
```

Contracts:

- Zed can start a Pi-backed session.
- Session prompt streams back to Zed.
- Pi session list/load works.
- Permission gates for bash/write/edit are visible in Zed.
- Model/thinking config can be changed or documented as fixed.

Known gaps from repo:

- Pi bridge does not expose ACP HTTP/SSE MCP transport.
- Pi bridge does not use ACP fs write path; writes stay on Pi tool paths.
- Pi custom extension UI requests are not yet bridged.

Decision:

- Do not build ACP adapter.
- If gaps block usage, patch/fork `acp-adapter` first.

## Phase 2: Pi Runtime Package Set

Adopt selected packages from `spences10/my-pi`, not full custom runtime:

- `@spences10/pi-mcp`
- `@spences10/pi-lsp`
- `@spences10/pi-context`
- `@spences10/pi-recall`
- `@spences10/pi-telemetry`
- `@spences10/pi-redact`
- `@spences10/pi-skills`
- `@spences10/pi-team-mode` only if it beats simpler subagent extension

Contracts:

- Package install works with current Pi.
- Project/global config is understandable and reproducible.
- MCP config can be project scoped.
- Telemetry/context data is local and inspectable.
- Redaction is applied before logs/memory/session export.

Risk:

- Requires Node `>=24.15.0`; dotfiles/Nix may need only runtime prerequisite support, not live config generation.

Decision:

- Prefer selected `pi install npm:@spences10/...` packages.
- Do not create a local Pi package unless a selected package cannot be configured or upstream-patched.

## Phase 3: Permissions And Scoped Capabilities

Adopt by default:

- Pi built-in gates
- `MasuRii/pi-permission-system`
- ACP permission flow through `acp-adapter`

Policy baseline:

- Allow read-only code exploration.
- Allow local test execution with configured command patterns.
- Allow patch/edit/write only through Pi permission UI.
- Ask for destructive local git operations.
- Deny secret reads, credential export, remote publish, package publish, deployment, and `git push` by default.
- Hide denied tools from the agent prompt where possible.

Contracts:

- Denied tools are hidden before model start.
- Runtime enforcement still blocks forbidden calls.
- Bash pattern controls work for common safe/unsafe commands.
- MCP tool permissions can be restricted by server/tool.
- Subagent permission prompts forward to the interactive parent.

Decision:

- Do not build a policy engine.
- Cedar is out of MVP.
- Local code is allowed only for generating/checking config examples.

## Phase 3.5: Pi Hook / Tool Responsibility Model

Use Pi ecosystem extension hooks and package lifecycle before custom tools. The core rule:

```text
hook = automatic capture, restore, reminder, and guardrail
tool = intentional search, checkpoint, correction, and recovery
system prompt = small behavior contract
```

Hook-first responsibilities:

| Timing | Primary action | Candidate owner |
| --- | --- | --- |
| session start | detect project, restore recent context, check memory health | Engram Pi package, Magic Context |
| user prompt submit / input | save prompt, optionally search related memory, inject compact high-confidence hints | Engram HTTP event capture, Magic Context auto search |
| post response / task summary | passive capture, candidate learning extraction, session summary update | Engram `mem_capture_passive`, Magic Context dreamer |
| compaction after / summary after | restore memory context and recent project summary | Engram compaction recovery, Magic Context historian |
| session end | save session summary and close lifecycle | Engram `mem_session_summary` / `mem_session_end` |

Agent-visible tools should stay few and high-level:

- `memory_search(query)`
- `memory_checkpoint(what_changed, why, files, decisions)`
- `memory_recover(topic)`
- `memory_update(id, correction)`

Implementation rule:

- Do not create these as local custom tools while Engram or Magic Context already exposes equivalent `mem_*` / `ctx_*` tools.
- If a friendlier tool name is needed, make it a prompt alias or thin wrapper only after checking the existing MCP schema.
- Avoid writing permanent memories from hooks directly unless the tool has a passive/candidate mode. Permanent project/global memory needs a promotion gate.

Noise controls:

- High threshold for automatic recall hints.
- Low result count.
- Redaction before storage and injection.
- Project disambiguation must fail loudly; agent must not guess.
- Do not run two automatic memory writers at the same time until duplicate/conflict behavior is tested.

## Phase 4: Codebase Context

Adopt:

- `codedb` for fast structural search, task-shaped context, dependency graph, snapshots, and codebase review surface.
- `lsmcp` for LSP-grounded diagnostics, definitions, references, rename, hover, and MoonBit/TypeScript/Rust language-server support.
- `@spences10/pi-lsp` if it covers enough LSP workflow without extra lsmcp complexity.

Contracts:

- `codedb_context` answers task-shaped context queries.
- `codedb_deps` gives dependency neighborhoods for changed files.
- `codedb` sensitive-file blocking is enabled and verified.
- `lsmcp get_project_overview -> search_symbols -> get_symbol_details` works in TypeScript and MoonBit repos.
- Diagnostics and references are trusted enough for edit planning.

Decision:

- No local code graph engine.
- No custom viewer in MVP.
- Review visualization starts as query presets and textual/JSON summaries:
  - `change_neighborhood`
  - `risk_surface`
  - `entrypoints`
  - `review_path`
  - `diagnostic_surface`

## Phase 5: Memory And Reflection

Adopt first for durable memory protocol:

- `Gentleman-Programming/engram`

Why:

- `engram setup pi` installs Pi integration instead of requiring a custom package.
- Pi package has two routes: HTTP event capture for lifecycle/passive events and MCP gateway for agent-visible `mem_*` tools.
- It supports compact memory tools for current project, context, prompt save, passive capture, session summary, conflict/judge, and doctor checks.
- It is agent-agnostic and also supports Codex, Claude Code, Gemini, OpenCode, VS Code, Cursor/Windsurf through MCP or setup flows.

Adopt/compare for context compaction and auto recall:

- `cortexkit/magic-context`

Why:

- It has a Pi extension.
- It manages context compression, project memory, dreamer consolidation, sidekick context, key-file pins, user memories, and doctor checks.
- It shares SQLite memory across Pi and OpenCode.

Evaluate second:

- Running Engram and Magic Context together only after checking duplicate memory writes, prompt injection conflicts, and compaction-hook ordering.

Defer:

- `a-mem-mcp` and `memory-graph` until graph relationships are proven necessary.

Contracts:

- Memory is local and inspectable.
- Project memory can be separated from user/global memory.
- Unverified reflection does not become permanent global memory automatically.
- Memory retrieval improves repeated tasks.
- Redaction happens before storage.
- Hook-based capture works without relying on the agent remembering to call tools.
- Agent-visible tools remain available for intentional search/checkpoint/recover/update.

Local allowed:

- small bridge documents/prompts that define promotion rules
- config examples
- memory acceptance tests

Local disallowed:

- new memory DB
- new vector store
- new dreamer/reflection engine

## Phase 6: Session Search And Monitoring

Adopt:

- `ai-sessions-mcp` for Claude/Codex/Gemini/opencode.
- `@spences10/pi-telemetry`, `@spences10/pi-recall`, and Magic Context for Pi side data.

Known gap:

- `ai-sessions-mcp` does not list Pi as a supported source in the README.

Decision:

- First test whether Pi session files can be read through existing paths.
- If not, write a Pi source adapter upstream for `ai-sessions-mcp`.
- Local adapter is allowed only if upstream contribution is blocked or slow.

Contracts:

- Search Codex sessions by keyword.
- List recent sessions by project.
- Retrieve paginated session content.
- Add Pi session search either upstream or via thin importer.
- No secrets in exported/searchable snippets.

## Phase 7: Code Mode

Adopt first:

- `pctx`

Why:

- It aggregates upstream MCP servers.
- It exposes tools through Code Mode.
- It runs generated code in a Deno sandbox with no filesystem/env/network except configured hosts.
- It keeps auth out of LLM-visible code.

Adopt second:

- `mcpc` for scriptable MCP composition with JSON output, persistent sessions, OAuth, tasks.

Use conditionally:

- `ipybox` for Python/IPython workflows requiring stateful notebooks, shell, and MCP Python APIs.
- Cloudflare Agents Code Mode only for Cloudflare-hosted workflows.

Contracts:

- Code Mode can call codedb/lsmcp/memory/search capabilities.
- Generated code cannot access raw filesystem/env/network.
- MCP auth secrets are never exposed to generated code.
- Long-running MCP tasks can detach/rejoin or report status.

Decision:

- Do not build `code.execute`.
- Do not build a Deno sandbox.
- Local code allowed only for pctx/mcpc config and smoke tests.

## Phase 8: Subagents

Adopt first:

- `mjakl/pi-subagent`

Why:

- Minimal surface.
- Supports `spawn` and `fork`.
- Supports parallel execution.
- Has depth/cycle guards.
- Requires approval for project-local agents.

Evaluate second:

- `tintinweb/pi-subagents`
- `@spences10/pi-team-mode`

Contracts:

- Read-only explorer subagent works.
- Reviewer/tester subagents can run in parallel.
- Permission requests from subagents are routed to parent where needed.
- Parent receives final result without flooding context with child tool traces.

Decision:

- No local subagent orchestration.

## Phase 9: Verification / Review / Improvement Loop

Adopt existing mizchi tools:

- `chaosbringer` for black-box/fault testing.
- `vlmkit` for visual regression and semantic screenshot review.
- `flaker` for flaky/test selection intelligence.
- `actrun` for local GitHub Actions reproduction.
- `similarity` for AST-level duplication/similarity.
- `codedb`/`lsmcp` for dependency and diagnostics surfaces.

MVP loop:

1. Agent makes or proposes change.
2. `codedb` produces changed-file dependency neighborhood.
3. `lsmcp` checks diagnostics/references.
4. Relevant test tool runs.
5. Visual/chaos/flaky checks run only when applicable.
6. Findings go to memory only through Magic Context/Engram promotion rules.

Decision:

- No custom review UI in MVP.
- No graph viewer until query presets prove insufficient.

## Phase 10: Codex And Multi-Agent History

Adopt:

- pi-ai Codex OAuth if current Pi supports it.
- Codex CLI as a delegated external agent using native `~/.codex`.
- `ai-sessions-mcp` for Codex session search.

Decision:

- Do not extract/reuse Codex OAuth tokens directly.
- Direct token handling is out of MVP.

Contracts:

- Pi can use Codex provider through supported auth path.
- Codex CLI can be invoked separately if needed.
- Codex sessions are searchable through `ai-sessions-mcp`.
- No credential material enters memory, telemetry, or session exports.

## Phase 11: Local / Open-Weight Models

Adopt:

- Pi custom model configuration.
- pi-ai existing providers.
- OpenAI-compatible endpoints.
- Ollama / llama.cpp / vLLM / LM Studio as provider endpoints, not a local router.

Contracts:

- At least one small local model handles memory/session summarization.
- At least one stronger open-weight model handles read-only code review.
- Patch-authoring stays on the strongest reliable model until local models pass tests.

Routing stays manual/config-driven:

| Task | Default |
| --- | --- |
| memory extraction | small local/open-weight |
| session summarization | small local/open-weight |
| codebase map | medium local/open-weight |
| patch authoring | strongest reliable hosted/local model |
| review critic | different model/provider from author |

Decision:

- No provider router in MVP.

## Phase 12: APM And Distribution

Adopt:

- `microsoft/apm`

Contracts:

- `apm.yml` can declare skills/plugins/MCP servers needed for project use.
- `apm.lock.yaml` pins dependencies.
- APM audit catches drift/security issues.
- Project packages install without mutating unrelated live config unexpectedly.

Decision:

- Do not build a package manager.
- This repo stores examples and project-specific manifests only.

## Phase 13: vibe-lang And MoonBit

vibe-lang:

- Keep as research for an agent action DSL.
- Do not use in MVP.
- Do not build local runtime/compiler/LSP/tooling.

MoonBit:

- Keep as research for deterministic kernels only after TypeScript/tool composition proves the data model.
- Good future targets:
  - graph pruning scorer
  - receipt validator
  - capability spec checker
  - stable context selection kernel

Decision:

- Neither vibe-lang nor MoonBit blocks the MVP.

## MVP Acceptance Criteria

MVP is complete when:

- Zed can operate Pi through `acp-adapter`.
- Pi uses selected existing packages for MCP, context, telemetry, redaction, skills, and subagents.
- Permission rules block or ask for risky filesystem/git/network/bash operations.
- `codedb` and `lsmcp` provide codebase context without custom graph code.
- Engram Pi package is configured and `mem_current_project`, `mem_context`, `mem_save_prompt`, `mem_capture_passive`, and session lifecycle tools are smoke-tested.
- Magic Context is either configured for context management or explicitly rejected/deferred because it conflicts with Engram.
- Codex/Claude/Gemini/opencode sessions are searchable through `ai-sessions-mcp`.
- Pi session search has either existing support, an upstream adapter, or a tiny local importer with deletion path.
- Code Mode uses `pctx` or `mcpc`; no local sandbox exists.
- Verification loop can run at least one code-intelligence check and one test/review tool.
- At least one local/open-weight model is configured for low-risk summarization.
- APM manifest or config examples document reproducible setup.

## Implementation Order

1. Write evaluation docs, not code.
2. Validate `acp-adapter` with Zed and Pi.
3. Install selected `my-pi` packages into a disposable Pi config dir.
4. Validate `pi-permission-system` with safe/unsafe commands and MCP tools.
5. Validate `codedb` current release and `lsmcp` on a real TypeScript repo.
6. Validate Engram for Pi with hook-first memory lifecycle.
7. Validate Magic Context separately for context compaction and auto recall hints.
8. Decide Engram-only, Magic-only, or split responsibility. Do not enable both automatic memory writers until this decision is made.
9. Validate `ai-sessions-mcp` for Codex and Claude histories.
10. Decide Pi session search path: upstream adapter vs tiny importer.
11. Validate `pctx` with codedb/lsmcp as upstream MCPs.
12. Validate `mjakl/pi-subagent`.
13. Add APM manifest/config examples.
14. Configure local/open-weight models.
15. Only then create `tools/pi-workbench-adapters/` if a missing contract remains.

## Immediate Next Files To Create

```text
dot-config/agents/pi-workbench/README.md
dot-config/agents/pi-workbench/reuse-inventory.md
dot-config/agents/pi-workbench/decisions.md
dot-config/agents/pi-workbench/candidate-evaluations/acp-adapter.md
dot-config/agents/pi-workbench/candidate-evaluations/my-pi.md
dot-config/agents/pi-workbench/candidate-evaluations/pi-permission-system.md
dot-config/agents/pi-workbench/candidate-evaluations/codedb.md
dot-config/agents/pi-workbench/candidate-evaluations/lsmcp.md
dot-config/agents/pi-workbench/candidate-evaluations/engram.md
dot-config/agents/pi-workbench/candidate-evaluations/magic-context.md
dot-config/agents/pi-workbench/candidate-evaluations/ai-sessions-mcp.md
dot-config/agents/pi-workbench/candidate-evaluations/pctx.md
dot-config/agents/pi-workbench/candidate-evaluations/subagents.md
dot-config/agents/pi-workbench/verification/acceptance-matrix.md
```

## Open Questions

1. Pi session search: upstream PR to `ai-sessions-mcp` or local importer?
2. Engram vs Magic Context: Engram-only, Magic-only, or split Engram durable memory + Magic context compaction?
3. `@spences10/pi-lsp` vs `lsmcp`: is lsmcp's richer tool set worth the extra server?
4. `pctx` vs `mcpc`: use pctx for Code Mode, mcpc for compatibility tests, or both?
5. APM manifest scope: project-only examples or real repo-level install manifest?

## Rejection Log

Rejected for MVP:

- custom ACP server
- custom Deno Code Mode runtime
- custom memory database
- custom graph viewer
- custom permission engine
- custom provider router
- custom subagent orchestration
- custom package manager

Deferred:

- vibe-lang action language
- MoonBit deterministic kernels
- Cedar policy
- graph memory
- Cloudflare-hosted Code Mode
