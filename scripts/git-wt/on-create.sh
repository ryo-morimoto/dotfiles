#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${TMUX:-}" ]] || ! command -v tmux >/dev/null 2>&1; then
	exit 0
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
branch_name="$(git branch --show-current 2>/dev/null || true)"
agent_cmd="${GIT_WT_AGENT:-}"

if [[ -z "$repo_root" || -z "$branch_name" ]]; then
	exit 0
fi

repo_name="$(basename "$repo_root")"
worktree_path="$(pwd -P)"
window_name="${repo_name}:${branch_name}"
window_name="${window_name//\//-}"
window_name="${window_name:0:80}"

window_id="$({
	tmux list-windows -a -F '#{window_id}\t#{window_name}'
} | awk -F '\t' -v name="$window_name" '$2 == name { print $1; exit }')"

created_window=0
if [[ -z "$window_id" ]]; then
	window_id="$(tmux new-window -P -F '#{window_id}' -n "$window_name" -c "$worktree_path")"
	created_window=1
fi

tmux set-option -w -q -t "$window_id" @git_wt_path "$worktree_path"
tmux set-option -w -q -t "$window_id" @git_wt_branch "$branch_name"

if [[ "$created_window" -eq 1 && -n "$agent_cmd" ]]; then
	case "$agent_cmd" in
	claude | opencode | codex)
		if command -v "$agent_cmd" >/dev/null 2>&1; then
			tmux send-keys -t "$window_id" "$agent_cmd" C-m
		fi
		;;
	esac
fi

tmux select-window -t "$window_id"
