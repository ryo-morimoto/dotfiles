#!/usr/bin/env bash

set -euo pipefail

if ! command -v beacon >/dev/null 2>&1; then
	printf "beacon command not found in PATH\n"
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

rows="$(beacon scan --scope window --all-sessions --template '{{range .Windows}}{{.SessionName}}:{{.WindowIndex}}{{"\t"}}{{.WindowName}}{{"\t"}}{{len .Signals}}{{"\t"}}{{range .Signals}}{{.State}} {{end}}{{"\n"}}{{end}}')"

if [ -z "${rows}" ]; then
	printf "No tmux windows found\n"
	printf "Press Enter to close..."
	read -r _
	exit 0
fi

selection="$(
	printf '%s\n' "${rows}" |
		fzf \
			--delimiter=$'\t' \
			--with-nth=1,2,4 \
			--prompt='beacon window> ' \
			--header='Enter: jump window, Esc: cancel'
)"

if [ -z "${selection}" ]; then
	exit 0
fi

target="$(printf '%s' "${selection}" | cut -f1)"
session="${target%%:*}"
window_index="${target#*:}"

tmux switch-client -t "${session}"
tmux select-window -t "${session}:${window_index}"
