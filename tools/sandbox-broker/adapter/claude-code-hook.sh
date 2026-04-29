#!/usr/bin/env bash
# Claude Code PreToolUse hook — sandbox-broker adapter
#
# Input (stdin): PreToolUseHookInput JSON
#   Required: session_id, transcript_path, cwd, hook_event_name, tool_name, tool_input, tool_use_id
#   Optional: permission_mode, agent_id, agent_type
#
# Output (stdout on exit 0): SyncHookJSONOutput JSON with permissionDecision
# Output (stderr on exit 2): error message fed back to Claude
#
# Contract source: @anthropic-ai/claude-agent-sdk sdk.d.ts (PreToolUseHookInput, PreToolUseHookSpecificOutput)
#
# Env:
#   SANDBOX_BROKER_SOCK (default: .sandbox/broker.sock relative to base repo root)
#   SANDBOX_BROKER_ENABLED (default: 1, set to 0 to bypass)

set -euo pipefail

if [[ "${SANDBOX_BROKER_ENABLED:-1}" != "1" ]]; then
	exit 0
fi

# Discover socket path from base repo root (handles worktrees)
if [[ -n "${SANDBOX_BROKER_SOCK:-}" ]]; then
	SOCK="$SANDBOX_BROKER_SOCK"
else
	GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
	if [[ -n "$GIT_COMMON_DIR" ]]; then
		BASE_ROOT=$(cd "$GIT_COMMON_DIR/.." && pwd -P)
	else
		BASE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
	fi
	SOCK="${BASE_ROOT}/.sandbox/broker.sock"
fi

if [[ ! -S "$SOCK" ]]; then
	# No broker running for this project — passthrough silently
	exit 0
fi

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // empty')

build_operation() {
	case "$TOOL_NAME" in
	Read)
		local path
		path=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
		if [[ -n "$path" ]]; then
			jq -n --arg path "$path" '{"kind": "FileRead", "detail": {"path": $path}}'
			return
		fi
		;;
	Edit | Write)
		local path
		path=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
		if [[ -n "$path" ]]; then
			jq -n --arg path "$path" '{"kind": "FileWrite", "detail": {"path": $path}}'
			return
		fi
		;;
	Bash)
		local cmd
		cmd=$(echo "$TOOL_INPUT" | jq -r '.command // empty')
		if [[ -n "$cmd" ]]; then
			local argv
			argv=$(echo "$cmd" | jq -R 'split(" ")')
			jq -n --argjson argv "$argv" '{"kind": "CommandExec", "detail": {"argv": $argv}}'
			return
		fi
		;;
	Glob | Grep | WebFetch | WebSearch)
		echo ""
		return
		;;
	*)
		echo ""
		return
		;;
	esac
	echo ""
}

OPERATION=$(build_operation)

if [[ -z "$OPERATION" ]]; then
	# Passthrough: no policy-relevant operation
	jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "sandbox-broker: not a policy-controlled tool"
    }
  }'
	exit 0
fi

# Query broker via UDS
RESPONSE=$(curl -s -m 2 --unix-socket "$SOCK" \
	-X POST "http://localhost/evaluate" \
	-H "Content-Type: application/json" \
	-d "$OPERATION" 2>/dev/null) || {
	# Broker unreachable (crashed, stale socket, etc.) — passthrough silently
	exit 0
}

OUTCOME=$(echo "$RESPONSE" | jq -r '.outcome // "deny"')
RATIONALE=$(echo "$RESPONSE" | jq -r '.rationale // ""')

case "$OUTCOME" in
allow)
	jq -n --arg reason "$RATIONALE" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": ("sandbox-broker: " + (if $reason == "" then "allowed" else $reason end))
      }
    }'
	exit 0
	;;
deny)
	jq -n --arg reason "$RATIONALE" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": ("sandbox-broker: " + (if $reason == "" then "denied by policy" else $reason end))
      }
    }'
	exit 0
	;;
escalate)
	jq -n --arg reason "$RATIONALE" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": ("sandbox-broker: " + (if $reason == "" then "requires approval" else $reason end))
      }
    }'
	exit 0
	;;
esac
