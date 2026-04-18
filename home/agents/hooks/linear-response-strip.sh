#!/usr/bin/env bash
# Claude Code PostToolUse hook.
#
# For Linear MCP write tools (mcp__linear-*__(save_issue|save_project)),
# replace the full-object response with {id, url, ok: true} via
# hookSpecificOutput.updatedMCPToolOutput. Reason: Linear server returns
# description echo + timestamps + UUIDs (~1382 chars avg) where the agent
# only needs id/url. The verbose response inflates cache_create on every
# subsequent turn.
#
# Contract:
#   stdin  = Claude Code PostToolUse hook payload (JSON: tool_name,
#            tool_input, tool_response, ...)
#   stdout = JSON with hookSpecificOutput.updatedMCPToolOutput when the
#            response is an object containing `id`; otherwise empty (the
#            original response flows through unchanged).
#   log    = /tmp/claude-code-hooks.jsonl — one JSON line per invocation
#            with {ts, tool, status, bytes_before, bytes_after, reason?}.
#
# Policy:
#   - Fail-open. Any jq error, unexpected shape, or missing field →
#     passthrough + log. Never blocks a tool_result from reaching the agent.
#   - Only activates for MCP tools (matcher narrows this upstream); still
#     guards internally in case matcher broadens.

LOG=/tmp/claude-code-hooks.jsonl
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)
RESP=$(printf '%s' "$INPUT" | jq -c '.tool_response // ""' 2>/dev/null || true)
BYTES_BEFORE=${#RESP}

log_event() {
	local status=$1 after=$2 reason=${3-}
	jq -cn \
		--arg ts "$TS" \
		--arg tool "$TOOL" \
		--arg status "$status" \
		--argjson before "$BYTES_BEFORE" \
		--argjson after "$after" \
		--arg reason "$reason" '
      {ts:$ts, tool:$tool, status:$status, bytes_before:$before, bytes_after:$after}
      + (if $reason != "" then {reason:$reason} else {} end)
    ' 2>/dev/null >>"$LOG" || true
}

# Derive stripped payload. Accept tool_response as either a JSON object
# (when the hook runtime pre-parses MCP output) or a string containing
# JSON (common for text content blocks).
STRIPPED=$(printf '%s' "$RESP" | jq -c '
  (if type == "string" then (try fromjson catch null) else . end) as $r
  | if ($r | type) == "object" and ($r | has("id"))
    then {id: $r.id, url: ($r.url // null), ok: true}
    else empty end
' 2>/dev/null)

if [ -z "$STRIPPED" ]; then
	log_event passthrough "$BYTES_BEFORE" no_id_or_unparseable
	exit 0
fi

OUTPUT=$(jq -cn --argjson stripped "$STRIPPED" '
  {hookSpecificOutput: {hookEventName: "PostToolUse", updatedMCPToolOutput: $stripped}}
' 2>/dev/null)

if [ -z "$OUTPUT" ]; then
	log_event parse_failed "$BYTES_BEFORE" output_build_failed
	exit 0
fi

BYTES_AFTER=${#STRIPPED}
log_event applied "$BYTES_AFTER"
printf '%s\n' "$OUTPUT"
