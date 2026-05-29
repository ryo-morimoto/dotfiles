# Reuse Inventory

Date checked: 2026-05-29

## Capability Map

| Capability | Candidate | Source / Package | Current disposition |
| --- | --- | --- | --- |
| Zed ACP bridge | `beyond5959/acp-adapter` | GitHub HEAD `491151b` | Adopt first; patch upstream if ACP bridge gaps block use. |
| Pi MCP package | `@spences10/pi-mcp` | npm `0.0.37` | Adopt if install works with current Pi. |
| Pi LSP package | `@spences10/pi-lsp` | npm `0.0.33` | Compare with `lsmcp`; keep if it covers common LSP flow. |
| Pi context package | `@spences10/pi-context` | npm `0.0.24` | Adopt for local context sidecar if inspectable. |
| Pi recall package | `@spences10/pi-recall` | npm `0.0.13` | Adopt for Pi-native recall after redaction check. |
| Pi telemetry package | `@spences10/pi-telemetry` | npm `0.0.23` | Adopt if logs are local and queryable. |
| Pi redaction package | `@spences10/pi-redact` | npm `0.0.12` | Required before memory/session export. |
| Pi skills package | `@spences10/pi-skills` | npm `0.0.28` | Adopt for skill loading if protected-skill behavior is clear. |
| Pi team mode | `@spences10/pi-team-mode` | npm `0.0.31` | Disposable install passed; evaluate behavior after minimal subagent support. |
| Permission system | `MasuRii/pi-permission-system` | GitHub HEAD `ccebbf4` | Adopt before building any policy engine. |
| Durable memory | `Gentleman-Programming/engram` | GitHub HEAD `6bfe33d`; Go build/test passed, binary reports `v1.16.0` | Adopt first for Pi memory lifecycle. |
| Context compaction | `cortexkit/magic-context` | GitHub HEAD `d9728ce`; npm `@cortexkit/magic-context@0.21.8`, `@cortexkit/pi-magic-context@0.21.8` | Evaluate separately; do not run as second automatic writer yet. |
| Session search | `yoavf/ai-sessions-mcp` | GitHub HEAD `3bc3186` | Adopt for Codex/Claude/Gemini/opencode; Pi source is a gap. |
| Code Mode | `portofcontext/pctx` | GitHub HEAD `0b9312d`; npm `@portofcontext/pctx@0.7.1` | Adopt first for sandboxed Code Mode over MCP. |
| MCP CLI composition | `@apify/mcpc` | npm `0.3.0` | Use for shell/JSON compatibility checks. |
| Code intelligence | `justrach/codedb` | GitHub HEAD `e89e110`; npm `codedb` unpublished | Use GitHub source path; npm package is not available under `codedb`. |
| LSP MCP | `mizchi/lsmcp` | GitHub HEAD `f2fb91d`; npm `@mizchi/lsmcp@0.10.0` | Use npm package path. |
| Subagents | `mjakl/pi-subagent` | GitHub HEAD `b7f0360`; npm `@mjakl/pi-subagent@2.1.0` | Disposable install passed; adopt first. |
| Package/distribution | `microsoft/apm` | GitHub HEAD `ec771e5`; npm `@microsoft/apm` not found | Use repo-documented install path, not assumed npm package. |
| Local/open models | Pi custom model config / pi-ai providers | `@earendil-works/pi-coding-agent@0.77.0` observed | Configure endpoints; do not build a router. |
| Experiments | `vibe-lang`, MoonBit | GitHub/repo research only | Deferred from MVP. |

## Reuse Rule

A local adapter is justified only when:

1. An existing candidate is installed or checked against its current source.
2. The candidate fails a concrete contract in `verification/acceptance-matrix.md`.
3. The gap cannot be handled by config or a small upstream fix in the near term.
4. The local code has a deletion path once upstream support lands.
