#!/usr/bin/env bash
# pane-haiku.sh — Claude Code Stop hook
# Generates a haiku from the last assistant message and sets it as tmux pane title.

set -euo pipefail

# Read hook payload from stdin
INPUT=$(cat)

# Prevent infinite loops
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
	exit 0
fi

# Only run inside tmux
[ -n "${TMUX:-}" ] || exit 0

# Extract last assistant message (truncate to 300 chars to keep prompt small)
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' | head -c 300)
[ -n "$LAST_MSG" ] || exit 0

# Generate haiku in background so we don't block Claude
(
	PROMPT="以下の作業内容を日本語の俳句（五七五）1句で詠め。句のみ出力。余計な説明不要。

作業内容:
${LAST_MSG}"

	HAIKU=$(claude -p --model haiku "$PROMPT" 2>/dev/null | head -1)

	if [ -n "$HAIKU" ]; then
		tmux select-pane -T "$HAIKU"
	fi
) &
disown

exit 0
