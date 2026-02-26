#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${TMUX:-}" ]] || ! command -v tmux >/dev/null 2>&1; then
	exit 0
fi

worktree_path="$(pwd -P)"
current_window_id="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"

while IFS=$'\t' read -r window_id window_path; do
	if [[ -z "$window_path" || "$window_path" != "$worktree_path" ]]; then
		continue
	fi
	if [[ -n "$current_window_id" && "$window_id" == "$current_window_id" ]]; then
		continue
	fi
	tmux kill-window -t "$window_id" || true
done < <(tmux list-windows -a -F '#{window_id}\t#{@git_wt_path}')

if [[ -n "$current_window_id" ]]; then
	current_path="$(tmux show-options -w -q -t "$current_window_id" -v @git_wt_path 2>/dev/null || true)"
	if [[ "$current_path" == "$worktree_path" ]]; then
		printf 'git-wt cleanup: close current tmux window manually if needed.\n' >&2
	fi
fi
