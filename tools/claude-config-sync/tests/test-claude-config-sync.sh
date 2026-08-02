#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sync_script=$(cd -- "$script_dir/.." && pwd)/claude-config-sync
test_dir=$(mktemp -d)

cleanup() {
	rm -rf -- "$test_dir"
}
trap cleanup EXIT

fail() {
	printf 'test-claude-config-sync: %s\n' "$1" >&2
	exit 1
}

source_config="$test_dir/repository/settings.json"
live_config="$test_dir/home/settings.json"
mkdir -p "$(dirname "$source_config")" "$(dirname "$live_config")"

printf '%s\n' '{"effortLevel":"high","model":"model[1m]","env":{"OTEL_LOG_USER_PROMPTS":"0"}}' >"$source_config"
printf '%s\n' '{"effortLevel":"medium"}' >"$live_config"

"$sync_script" --source "$source_config" --live "$live_config" --push >/dev/null
[[ $(jq -r '.effortLevel' "$live_config") == "high" ]] || fail "push did not update live config"
[[ -f $live_config.pre-dotfiles ]] || fail "push did not create a backup"

"$sync_script" --source "$source_config" --live "$live_config" --check >/dev/null

printf '%s\n' '{"effortLevel":"low","env":{"OTEL_LOG_USER_PROMPTS":"0"}}' >"$live_config"
if "$sync_script" --source "$source_config" --live "$live_config" --check >/dev/null 2>&1; then
	fail "check did not report drift"
else
	check_status=$?
	[[ $check_status -eq 2 ]] || fail "check returned an unexpected status"
fi

"$sync_script" --source "$source_config" --live "$live_config" --pull >/dev/null
[[ $(jq -r '.effortLevel' "$source_config") == "low" ]] || fail "pull did not update tracked source"

printf '%s\n' '{"path":"/home/user/ghq/github.com/private/repository"}' >"$live_config"
before_checksum=$(sha256sum "$source_config")
if "$sync_script" --source "$source_config" --live "$live_config" --pull >/dev/null 2>&1; then
	fail "pull accepted a private-looking path"
fi
after_checksum=$(sha256sum "$source_config")
[[ $before_checksum == "$after_checksum" ]] || fail "rejected pull changed tracked source"

printf 'test-claude-config-sync: ok\n'
