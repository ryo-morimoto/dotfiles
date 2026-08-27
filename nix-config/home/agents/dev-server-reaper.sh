#!/usr/bin/env bash
# dev-server-reaper: kill leftover dev servers (next dev, vite, ...) that AI
# agents (codex / claude / grok) started and never stopped.
#
#   dev-server-reaper orphans        # timer mode: age-based reaping
#   dev-server-reaper tree <pid>     # hook mode: reap matching descendants of <pid>
#   dev-server-reaper list           # dry run for either rule set
#
# Rules (orphans):
#   * process is owned by the current user and its command line matches a
#     dev-server pattern
#   * skip anything managed by a systemd .service unit (intentional daemons)
#   * skip anything whose environment carries DEVSERVER_KEEP=1 (explicit opt-out)
#   * no controlling tty  and age > IDLE_MAX  -> agent-spawned, unattended: kill
#   * any tty             and age > HARD_MAX  -> forgotten in a pane: kill

idle_max="${DEV_SERVER_REAPER_IDLE_MAX_SEC:-10800}" # 3h
hard_max="${DEV_SERVER_REAPER_HARD_MAX_SEC:-86400}" # 24h
grace="${DEV_SERVER_REAPER_GRACE_SEC:-5}"

match_re='(^|[/ ])(next-server|next-(router|render)-worker[^ ]*|next(\.js)? (dev|start)|vite(\.js)?( |$)|nuxt (dev|preview)|astro (dev|preview)|remix vite:dev|webpack-dev-server|webpack serve|storybook (dev|serve)|turbo (run )?dev|(pnpm|npm|yarn|bun) (run )?dev|bun --hot)'
exclude_re='( build( |$)|dev-server-reaper)'

mode="${1:-list}"
root="${2:-}"

is_service() {
	# cgroup path ending in .service = systemd-managed, leave alone
	grep -qE '\.service$' "/proc/$1/cgroup" 2>/dev/null
}

is_kept() {
	tr '\0' '\n' <"/proc/$1/environ" 2>/dev/null | grep -qx 'DEVSERVER_KEEP=1'
}

descends_from() { # $1=pid $2=root
	local p="$1"
	while [ "$p" -gt 1 ]; do
		[ "$p" = "$2" ] && return 0
		p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
		[ -z "$p" ] && return 1
	done
	return 1
}

victims=()
while read -r pid tty etimes args; do
	[ "$pid" = "$$" ] && continue
	printf '%s' "$args" | grep -qE "$match_re" || continue
	printf '%s' "$args" | grep -qE "$exclude_re" && continue
	is_service "$pid" && continue
	is_kept "$pid" && continue
	reason=""
	case "$mode" in
	tree)
		[ -n "$root" ] || {
			echo "usage: dev-server-reaper tree <pid>" >&2
			exit 2
		}
		descends_from "$pid" "$root" && reason="descendant of $root"
		;;
	orphans | list)
		if [ "$tty" = "?" ] && [ "$etimes" -gt "$idle_max" ]; then
			reason="no tty, age ${etimes}s > ${idle_max}s"
		elif [ "$etimes" -gt "$hard_max" ]; then
			reason="age ${etimes}s > ${hard_max}s"
		fi
		;;
	*)
		echo "usage: dev-server-reaper {orphans|tree <pid>|list}" >&2
		exit 2
		;;
	esac
	[ -n "$reason" ] || continue
	echo "dev-server-reaper: pid=$pid tty=$tty ($reason): ${args:0:120}"
	victims+=("$pid")
done < <(ps -ww -o pid=,tty=,etimes=,args= -u "$(id -u)")

[ "${#victims[@]}" -gt 0 ] || exit 0
[ "$mode" = "list" ] && exit 0

kill -TERM "${victims[@]}" 2>/dev/null || true
sleep "$grace"
alive=()
for pid in "${victims[@]}"; do kill -0 "$pid" 2>/dev/null && alive+=("$pid"); done
[ "${#alive[@]}" -gt 0 ] && kill -KILL "${alive[@]}" 2>/dev/null || true
echo "dev-server-reaper: terminated ${#victims[@]} process(es) (${#alive[@]} needed SIGKILL)"
