# Pi Workbench Decisions

Date: 2026-05-29

## Accepted

| Decision | Why | Revisit when |
| --- | --- | --- |
| Reuse `acp-adapter` for Zed ACP to Pi. | It already targets Pi `--mode rpc` and ACP. | Zed session, streaming, load/list, or permission flow blocks daily use. |
| Store evaluation docs under `dot-config/agents/pi-workbench/`. | This repo treats live AI runtime config as mutable and keeps reviewed examples under `dot-config/agents/`. | A config becomes stable enough for Nix promotion after sustained use. |
| Start with docs and contract checks, not local source. | The plan explicitly rejects building a framework before candidate failure is proven. | A written contract fails and upstream patching is blocked or too slow. |
| Prefer hook lifecycle for automatic memory capture and tools for intentional memory actions. | It separates passive capture from explicit search, checkpoint, and correction. | Candidate schemas cannot express passive/candidate memories safely. |
| Keep Code Mode external through `pctx` first. | It already provides MCP aggregation and a Deno sandbox boundary. | `pctx` cannot call the required MCP servers or cannot protect secrets. |

## Rejected For MVP

| Rejected | Reason |
| --- | --- |
| local ACP server | Existing ACP-to-Pi adapter must fail first. |
| local permission engine | `pi-permission-system` covers the intended policy surface. |
| local memory database | Engram and Magic Context need evaluation first. |
| local Code Mode runtime | `pctx`, then `mcpc`, already cover the target shape. |
| local graph engine or viewer | `codedb` and `lsmcp` can provide textual and JSON context first. |
| local subagent orchestrator | `pi-subagent` and Pi team-mode candidates exist. |
| local package manager | APM exists and should own package/distribution semantics. |

## Deferred

| Topic | Reason |
| --- | --- |
| vibe-lang action DSL | Useful research, not required for MVP operation. |
| MoonBit deterministic kernels | Consider only after data models and check contracts stabilize. |
| Cedar policy | Too much policy-language surface before runtime permissions are validated. |
| graph memory | Prove durable memory and session search first. |
| Cloudflare-hosted Code Mode | Local Pi MVP does not require hosted agent state. |
