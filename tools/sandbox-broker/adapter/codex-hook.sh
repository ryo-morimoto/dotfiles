#!/usr/bin/env bash
# Codex CLI PreToolUse hook — sandbox-broker adapter
#
# Input (stdin): PreToolUseHookInput JSON
#   Required: session_id, cwd, hook_event_name, tool_name, tool_input, tool_use_id
#   Optional: transcript_path, model, turn_id
#
# Output behavior:
#   allow  → exit 0, no stdout (Codex treats silence as pass-through)
#   deny   → exit 0, stdout JSON with hookSpecificOutput.permissionDecision="deny"
#   escalate → exit 2, stderr reason (Codex blocks + shows reason to agent)
#
# Codex quirks vs Claude Code:
#   - permissionDecision "allow" is NOT enforced (fail-open), so we use silent exit 0
#   - tool_name mapping: Bash, apply_patch, read_file, list_dir, web_search, mcp_tool
#   - Bash tool_input.command is an array ["ls", "-la"], not a string "ls -la"
#
# Contract source: https://developers.openai.com/codex/hooks#pretooluse
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
	Bash)
		local argv
		argv=$(echo "$TOOL_INPUT" | jq -c '.command // empty')
		if [[ -n "$argv" && "$argv" != "null" ]]; then
			jq -n --argjson argv "$argv" '{"kind": "CommandExec", "detail": {"argv": $argv}}'
			return
		fi
		;;
	read_file)
		local path
		path=$(echo "$TOOL_INPUT" | jq -r '.path // empty')
		if [[ -n "$path" ]]; then
			jq -n --arg path "$path" '{"kind": "FileRead", "detail": {"path": $path}}'
			return
		fi
		;;
	apply_patch)
		local files
		files=$(echo "$TOOL_INPUT" | jq -c '.files // empty')
		if [[ -n "$files" && "$files" != "null" && "$files" != "[]" ]]; then
			local first_file
			first_file=$(echo "$files" | jq -r '.[0] // empty')
			if [[ -n "$first_file" ]]; then
				jq -n --arg path "$first_file" '{"kind": "FileWrite", "detail": {"path": $path}}'
				return
			fi
		fi
		local patch
		patch=$(echo "$TOOL_INPUT" | jq -r '.patch // empty')
		if [[ -n "$patch" ]]; then
			local patch_path
			patch_path=$(echo "$patch" | grep -oP '(?<=\+\+\+ b/).*' | head -1 || echo "")
			if [[ -n "$patch_path" ]]; then
				# Normalize to ./ prefix for policy matching
				if [[ "$patch_path" != ./* && "$patch_path" != /* ]]; then
					patch_path="./${patch_path}"
				fi
				jq -n --arg path "$patch_path" '{"kind": "FileWrite", "detail": {"path": $path}}'
				return
			fi
		fi
		echo ""
		return
		;;
	list_dir)
		local path
		path=$(echo "$TOOL_INPUT" | jq -r '.path // empty')
		if [[ -n "$path" ]]; then
			jq -n --arg path "$path" '{"kind": "FileRead", "detail": {"path": $path}}'
			return
		fi
		;;
	web_search)
		echo ""
		return
		;;
	mcp_tool | mcp__*)
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
	# Passthrough: not a policy-controlled tool → silent exit 0
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
	# Codex ignores permissionDecision="allow", so silent exit 0
	exit 0
	;;
deny)
	REASON="sandbox-broker: ${RATIONALE:-denied by policy}"
	jq -n --arg reason "$REASON" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": $reason
      }
    }'
	exit 0
	;;
escalate)
	# Codex doesn't support "ask", so use exit 2 to block + show reason
	echo "sandbox-broker: ${RATIONALE:-requires approval}" >&2
	exit 2
	;;
esac
