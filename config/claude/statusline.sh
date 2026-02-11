#!/usr/bin/env bash
# Claude Code statusline script for tmux
# Reads JSON from stdin and outputs formatted status to /tmp/claude-status

input=$(cat)
model=$(echo "$input" | jq -r '.model // "claude"')
cwd=$(echo "$input" | jq -r '.cwd // ""')
project=$(basename "$cwd" 2>/dev/null || echo "")

# Format: model | project
if [ -n "$project" ]; then
	status="#[fg=#f9e2af]$model#[fg=#cdd6f4] | #[fg=#94e2d5]$project"
else
	status="#[fg=#f9e2af]$model"
fi

echo "$status" >/tmp/claude-status
