# Local Smoke Receipts

Date: 2026-05-29
Host context: dotfiles repo on branch `feat/pi-agent-workbench-reuse-docs`

## Environment

```text
node --version -> v24.15.0
npm --version -> 11.12.1
npx --version -> 11.12.1
zed --version -> Zed preview 1.5.3 ddf89f77ef37fa2ae90aa8725dafc2566745fbb4
pi on PATH -> missing
npx @earendil-works/pi-coding-agent --version -> 0.77.0
```

Result: Node satisfies the selected Pi package requirement. Pi is usable through `npx`, but not installed on PATH.

## Pi Package Install

Command shape:

```sh
tmp=$(mktemp -d)
mkdir -p "$tmp/packages" "$tmp/agent"
printf '{"type":"module","dependencies":{}}\n' > "$tmp/packages/package.json"
HOME="$tmp" PI_CODING_AGENT_DIR="$tmp/agent" PI_PACKAGE_DIR="$tmp/packages" \
  npx @earendil-works/pi-coding-agent install npm:@spences10/pi-mcp
```

Observed:

- Empty `PI_PACKAGE_DIR` without `package.json` fails with `ENOENT: .../packages/package.json`.
- With `package.json`, install succeeds.
- These selected packages installed and appeared in `pi list`: `@spences10/pi-mcp`, `@spences10/pi-lsp`,
  `@spences10/pi-context`, `@spences10/pi-recall`, `@spences10/pi-telemetry`, `@spences10/pi-redact`,
  `@spences10/pi-skills`.
- `@spences10/pi-team-mode` installed in a separate disposable profile.

Pass/fail: pass for install/list; not a behavioral tool smoke.

## acp-adapter

Command:

```sh
git clone --depth 1 https://github.com/beyond5959/acp-adapter /tmp/acp-adapter
cd /tmp/acp-adapter
go test ./cmd/... ./internal/... ./pkg/...
go build -o /tmp/acp-adapter-bin ./cmd/acp
/tmp/acp-adapter-bin --help
```

Observed:

- Unit/package tests passed for `cmd`, `internal`, and `pkg`.
- Build passed.
- Help lists `--adapter pi`, `--pi-bin`, `--pi-provider`, `--pi-model`, `--pi-session-dir`, and
  `--pi-disable-gate`.
- Full `go test ./...` failed in `test/integration`: `TestE2EACPPlanUpdateMappedFromTurnPlanUpdated` expected at
  least two plan updates and got one.

Pass/fail: partial. Build and Pi flags pass; integration suite has one unrelated failing test; live Zed ACP session not
run from this non-interactive harness.

## codedb

Commands:

```sh
CODEDB_NO_TELEMETRY=1 codedb . tree
CODEDB_NO_TELEMETRY=1 codedb . search "pi agent workbench"
CODEDB_NO_TELEMETRY=1 codedb . outline dot-config/agents/pi-workbench/README.md
```

Observed:

- Indexing completed.
- Tree listed repo files including `dot-config/agents/pi-workbench`.
- Search returned `config.examples/apm/apm.yml` and `README.md`.
- Outline recognized the README as markdown.

Pass/fail: pass for CLI tree/search/outline. MCP tool call surface was not exercised.

## Engram

Command:

```sh
git clone --depth 1 https://github.com/Gentleman-Programming/engram /tmp/engram
cd /tmp/engram
go test ./...
go build -o /tmp/engram-bin ./cmd/engram
ENGRAM_DATA_DIR=/tmp/engram-data /tmp/engram-bin --help
```

Observed:

- All Go tests passed.
- Build passed.
- Binary reports `engram v1.16.0`.
- Help lists `setup [agent]` with `pi`, `mcp --tools=agent`, and memory/session commands.

Pass/fail: pass for build/test/help. Pi setup and MCP memory tool calls were not run because live Pi profile behavior was
not exercised.

## lsmcp

Commands:

```sh
npm view @mizchi/lsmcp version bin engines --json
npx -y @mizchi/lsmcp --help
```

Observed:

- npm package exists as `@mizchi/lsmcp@0.10.0`, not `lsmcp`.
- Node requirement is `>=22.0.0`.
- Help lists `init`, `index`, `doctor`, presets including `tsgo`, `typescript`, `rust-analyzer`, `gopls`, and `moonbit`.

Pass/fail: pass for package/help. Project LSP MCP tool calls were not exercised.

## Magic Context

Commands:

```sh
npm view @cortexkit/magic-context version bin engines --json
npm view @cortexkit/pi-magic-context version peerDependencies engines --json
npx -y @cortexkit/magic-context --version
```

Observed:

- CLI package exists as `@cortexkit/magic-context@0.21.8`, Node `>=24.0.0`.
- Pi plugin exists as `@cortexkit/pi-magic-context@0.21.8`.
- CLI version command reports `0.21.8`.

Pass/fail: pass for package/version. Conflict behavior with Engram was not exercised.

## pi-permission-system

Commands:

```sh
npm view pi-permission-system version peerDependencies engines --json
HOME="$tmp" PI_CODING_AGENT_DIR="$tmp/agent" PI_PACKAGE_DIR="$tmp/packages" \
  npx @earendil-works/pi-coding-agent install npm:pi-permission-system
```

Observed:

- npm package exists as `pi-permission-system@0.6.0`.
- Disposable Pi install succeeded and `pi list` showed `npm:pi-permission-system`.

Pass/fail: pass for install/list. Runtime allow/ask/deny behavior needs an interactive live Pi run.

## ai-sessions-mcp

Command:

```sh
git clone --depth 1 https://github.com/yoavf/ai-sessions-mcp /tmp/ai-sessions-mcp
cd /tmp/ai-sessions-mcp
go test ./...
go build -o /tmp/aisessions ./cmd/ai-sessions
/tmp/aisessions --help
```

Observed:

- All Go tests passed.
- Build passed.
- README lists supported sources: Claude Code, Gemini CLI, OpenAI Codex, and opencode.
- Source tree includes adapters for Claude, Codex, Copilot, Cursor, Gemini, Mistral, and opencode. No Pi adapter was
  present.

Pass/fail: pass for build/test/help; Pi session search remains a confirmed gap.

## pctx

Commands:

```sh
npm view @portofcontext/pctx version bin engines --json
npx -y @portofcontext/pctx --help
```

Observed:

- npm package exists as `@portofcontext/pctx@0.7.1`.
- Help lists `start` and `mcp` commands, including `pctx mcp init`, `pctx mcp dev`, and `pctx mcp add`.

Pass/fail: pass for package/help. Sandbox and upstream MCP execution were not exercised.

## mcpc

Commands:

```sh
npx @apify/mcpc --help
npx @apify/mcpc --json
```

Observed:

- Help lists `connect`, `tools-list`, `tools-call`, `tasks-*`, `--json`, and OAuth profile support.
- `--json` returned empty `sessions` and `profiles`, which is expected without active sessions.

Pass/fail: pass for CLI/help/JSON baseline. Tool call requires a configured MCP server session.

## Subagents

Commands:

```sh
npm view @mjakl/pi-subagent version peerDependencies engines --json
HOME="$tmp" PI_CODING_AGENT_DIR="$tmp/agent" PI_PACKAGE_DIR="$tmp/packages" \
  npx @earendil-works/pi-coding-agent install npm:@mjakl/pi-subagent
```

Observed:

- npm package exists as `@mjakl/pi-subagent@2.1.0`.
- Disposable Pi install succeeded and `pi list` showed `npm:@mjakl/pi-subagent`.

Pass/fail: pass for install/list. Spawn/fork behavior needs an authenticated live Pi run.

## APM

Commands:

```sh
uvx --from apm-cli apm --help
uvx --from apm-cli apm audit
uvx --from apm-cli apm install --help
uvx --from apm-cli apm install --dry-run --target codex
```

Observed:

- `apm --help` passed and listed `install`, `audit`, `compile`, `mcp`, `policy`, and other commands.
- `apm audit` in the example manifest directory exited 0 with "No apm.lock.yaml found".
- `apm install --help` confirmed `--dry-run` exists.
- First dry-run failed because `config.examples/apm/apm.yml` was missing required field `version`.
- After correcting the example to APM's `dependencies.mcp` shape, `apm install --dry-run --target codex` passed and
  reported four MCP dependencies: `codedb`, `lsmcp`, `ai-sessions`, and `engram`.

Pass/fail: pass for CLI/help/audit/dry-run. Full install was not run because example commands contain placeholders.

## Blocked Live Smokes

These were not run because they require interactive UI, credentials, local model endpoints, or live runtime state not
available in this non-interactive repo harness:

- Zed opens a Pi ACP session and streams a real prompt.
- ACP permission prompts visible in Zed.
- `pi-permission-system` runtime allow/ask/deny enforcement.
- Engram `engram setup pi` plus MCP `mem_*` calls from Pi.
- Magic Context and Engram duplicate-write/conflict test.
- `ai-sessions-mcp` search over live Codex/Claude/Pi sessions.
- `pctx` Code Mode execution against upstream MCP servers.
- APM full install because the example manifest is intentionally non-live and uses placeholder commands.
- Local/open model summarization/review because no endpoint/model config was provided.
