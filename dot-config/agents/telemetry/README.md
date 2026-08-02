# Agent telemetry

Claude Code と Codex の遅延を、ローカルの Grafana LGTM で比較するための運用手順。
telemetry の安定設定は `dot-config/config/claude/settings.json` と
`dot-config/config/codex/config.toml` を source of truth とする。Home Manager は
tracked content を生成せず、writable live config への copy/merge だけを行う。

## Architecture

```text
Claude Code ─┐
             ├─ OTLP/gRPC 127.0.0.1:4317 ─ Grafana LGTM
Codex ───────┘                                  ├─ Loki
                                               ├─ Prometheus
                                               ├─ Tempo
                                               └─ Grafana 127.0.0.1:3300
```

The container and dashboard are declared in
`nix-config/hosts/ryobox/agent-observability.nix`. The container image is pinned
by release and digest. Grafana and both OTLP ports bind only to loopback. Data is
kept under `/var/lib/agent-observability` for 14 days.

## Bootstrap

The image is not pulled implicitly during service startup. Before the first
rebuild, pull the exact image declared by the Nix module:

```bash
docker pull grafana/otel-lgtm:0.30.0@sha256:46ca028e294bd728e8e930a28e887f640a8f2a9533cc283f79bcc6ab73d2ffd8
sudo nixos-rebuild switch --flake ./nix-config#ryobox
```

After changing the pinned release and digest, use the explicit update path:

```bash
sudo systemctl start agent-observability-update.service
```

Useful checks:

```bash
systemctl is-active agent-observability.service
docker inspect --format '{{.State.Health.Status}}' agent-observability
curl --fail --silent http://127.0.0.1:3300/api/health | jq
ss -ltn | rg ':(3300|4317|4318)\b'
```

Open <http://127.0.0.1:3300/d/agent-latency>. Anonymous access is Viewer-only;
the dashboard itself is provisioned and not editable in the UI.

## Runtime configuration

Claude Code uses the `env` object in
`dot-config/config/claude/settings.json`. Home Manager copies it to the
writable `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "CLAUDE_CODE_ENHANCED_TELEMETRY_BETA": "1",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_TRACES_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://127.0.0.1:4317",
    "OTEL_LOG_TOOL_DETAILS": "1",
    "OTEL_LOG_USER_PROMPTS": "0",
    "OTEL_LOG_ASSISTANT_RESPONSES": "0",
    "OTEL_LOG_TOOL_CONTENT": "0",
    "OTEL_METRIC_EXPORT_INTERVAL": "10000",
    "OTEL_METRICS_INCLUDE_SESSION_ID": "false",
    "OTEL_METRICS_INCLUDE_ACCOUNT_UUID": "false"
  }
}
```

Codex stable settings live in `dot-config/config/codex/config.toml` and are
merged into the user-level `~/.codex/config.toml`. Project-local `.codex`
config cannot override telemetry routing.

```toml
[otel]
environment = "local"
log_user_prompt = false
exporter = { otlp-grpc = { endpoint = "http://127.0.0.1:4317" } }
trace_exporter = { otlp-grpc = { endpoint = "http://127.0.0.1:4317" } }
metrics_exporter = { otlp-grpc = { endpoint = "http://127.0.0.1:4317" } }
```

Restart each CLI after changing its config. The settings used by an already
running process do not change retroactively.

If Claude Code changes its writable live settings, review and run
`claude-config-pull` before rebuilding. Codex project trust and generated state
are preserved automatically by the merge and must not be copied into the
tracked base.

## Privacy boundary

- Raw prompts, assistant responses, and tool result bodies stay disabled.
- Claude's `OTEL_LOG_TOOL_DETAILS=1` is intentionally enabled so MCP server and
  tool names remain distinguishable. It can also expose command text, file
  paths, and tool arguments in native events and spans.
- The receiver and Grafana bind only to loopback and the backend retains data
  for 14 days.
- Do not add a Caddy virtual host or tailnet exposure for this stack.
- Backfill records contain only timestamps, IDs, model names, tool names,
  durations, counts, and explicit success flags.

## Native telemetry probe

Run one fresh session for each client after the backend is healthy. Use a
non-sensitive test directory and request one harmless successful tool call and
one expected failure. Do not use production repositories or secrets for the
probe.

Verify at least these records:

| Client | Logs / metrics | Traces |
| --- | --- | --- |
| Claude Code | `claude_code.session.count`, `claude_code.user_prompt`, `claude_code.api_request`, `claude_code.tool_result` | `claude_code.interaction`, `claude_code.llm_request`, `claude_code.tool`, `claude_code.tool.blocked_on_user`, `claude_code.tool.execution` |
| Codex | `codex.conversation_starts`, `codex.api_request`, `codex.tool_result`, `codex.tool.call.duration_ms` | native spans emitted by the installed CLI |

Inspect Prometheus metric names without guessing their OTLP normalization:

```bash
docker exec agent-observability \
  curl --fail --silent http://127.0.0.1:9090/api/v1/label/__name__/values \
  | jq -r '.data[]' \
  | rg '^(claude_code|codex|traces_)'
```

Inspect the resource service names received by Loki:

```bash
docker exec agent-observability \
  curl --fail --silent http://127.0.0.1:3100/loki/api/v1/label/service_name/values \
  | jq
```

Record the surface matrix for the installed version instead of assuming parity:

| Surface | Logs | Metrics | Traces |
| --- | --- | --- | --- |
| interactive `codex` | required | required | required |
| `codex exec` | required | may be absent; do not depend on it | required |
| `codex mcp-server` | not required | not required | not required |

The first dashboard revision deliberately keeps Codex's turn-level aggregation
separate from Claude's trace-root aggregation. If the native Codex spans expose
a stable turn ID and root duration, update the provisioned dashboard to use it.
Otherwise use transcript `task_started` / `task_complete` data from the backfill
tool; never coerce a missing value to zero.

## Backfill

The parser understands the locally observed Claude Code and Codex JSONL shapes.
It is a one-shot compatibility tool, not a daemon or permanent ingestion
pipeline. Start with a dry run:

```bash
python tools/agent-telemetry-backfill/backfill.py --days 14 --max-files 20
```

Send the selected records only after reviewing the counts:

```bash
python tools/agent-telemetry-backfill/backfill.py --days 14 --max-files 20 --send
```

Every record carries a deterministic `event.id` and
`telemetry.source=backfill`. Loki does not deduplicate by `event.id`, so avoid
re-sending the same range unless duplicate historical records are acceptable.
Malformed or unsupported JSONL lines are skipped and counted.

## Dashboard interpretation

Use at least ten turns per agent/model before comparing percentiles. For the
2–3 day baseline, compare:

1. turn duration p50/p95;
2. sum of LLM request durations per turn;
3. sum of tool durations per turn;
4. API-loop and tool-call counts per turn;
5. failure rate by tool and error type.

Normalize model duration by output tokens. Keep TTFT separate from generation
time. Group tool latency by MCP server where the native event exposes it. Show
missing TTFT or approval-wait values as null.

## Proxy cross-check

Do not make LiteLLM or another proxy the default provider. Introduce a temporary
profile only when native duration, token, model, or TTFT values look internally
inconsistent. Compare roughly 20 harmless turns, tag proxy observations with
`telemetry.source=proxy`, then restore the original provider. Keep proxy API
credentials outside the repository and use agenix if they ever become a stable
host prerequisite.

## References

- <https://code.claude.com/docs/en/monitoring-usage>
- <https://learn.chatgpt.com/docs/config-file/config-advanced#observability-and-telemetry>
- <https://grafana.com/docs/opentelemetry/docker-lgtm/>
