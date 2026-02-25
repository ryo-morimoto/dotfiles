#!/usr/bin/env bash

set -euo pipefail

if ! command -v beacon >/dev/null 2>&1; then
	printf "beacon command not found in PATH\n"
	printf "Press Enter to close..."
	read -r _
	exit 1
fi

refresh_seconds="${BEACON_STATUS_REFRESH_SECONDS:-2}"

while true; do
	clear
	printf "Beacon status (all tmux sessions)\n"
	printf "q: quit | r: refresh | w: window jump | p: pane focus | c: clean\n\n"

	if ! beacon scan --scope window --all-sessions --color=always; then
		printf "beacon scan failed\n"
	fi

	if read -rsn1 -t "${refresh_seconds}" key; then
		case "${key}" in
		q | Q)
			exit 0
			;;
		r | R) ;;
		w | W)
			bash "$HOME/.local/bin/beacon-window-jump.sh"
			exit 0
			;;
		p | P)
			bash "$HOME/.local/bin/beacon-pane-focus.sh"
			exit 0
			;;
		c | C)
			beacon clean >/dev/null 2>&1 || true
			;;
		$'\e')
			exit 0
			;;
		esac
	fi
done
