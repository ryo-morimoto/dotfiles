#!/usr/bin/env bash

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
	printf "jq command not found in PATH\n"
	printf "Press Enter to close..."
	read -r _
	exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
	printf "fzf command not found in PATH\n"
	printf "Press Enter to close..."
	read -r _
	exit 1
fi

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/beacon"

shopt -s nullglob
files=("${cache_dir}"/claude_*.json)
shopt -u nullglob

if [ "${#files[@]}" -eq 0 ]; then
	printf "No beacon signals found in %s\n" "${cache_dir}"
	printf "Press Enter to close..."
	read -r _
	exit 0
fi

rows="$(
	jq -rs '
    map(select(.environment.type == "tmux" and (.environment.pane_id // "") != ""))
    | sort_by(.updated_at)
    | reverse
    | unique_by(.environment.pane_id)
    | .[]
    | [
        (.environment.session_name // ""),
        ((.environment.window_index // 0) | tostring),
        ((.environment.pane_index // 0) | tostring),
        (.state // ""),
        (.environment.pane_title // .custom_message // ""),
        (.environment.pane_id // "")
      ]
    | @tsv
  ' "${files[@]}"
)"

if [ -z "${rows}" ]; then
	printf "No tmux pane signals found\n"
	printf "Press Enter to close..."
	read -r _
	exit 0
fi

selection="$(
	printf '%s\n' "${rows}" |
		fzf \
			--delimiter=$'\t' \
			--with-nth=1,2,3,4,5 \
			--prompt='beacon pane> ' \
			--header='Enter: focus pane, Esc: cancel'
)"

if [ -z "${selection}" ]; then
	exit 0
fi

session="$(printf '%s' "${selection}" | cut -f1)"
window_index="$(printf '%s' "${selection}" | cut -f2)"
pane_id="$(printf '%s' "${selection}" | cut -f6)"

tmux switch-client -t "${session}"
tmux select-window -t "${session}:${window_index}"
tmux select-pane -t "${pane_id}"
