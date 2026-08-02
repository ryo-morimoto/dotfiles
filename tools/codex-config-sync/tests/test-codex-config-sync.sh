#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sync_script=$(cd -- "$script_dir/.." && pwd)/codex-config-sync
test_dir=$(mktemp -d)

cleanup() {
	rm -rf -- "$test_dir"
}
trap cleanup EXIT

fail() {
	printf 'test-codex-config-sync: %s\n' "$1" >&2
	exit 1
}

base_config="$test_dir/base.toml"
live_config="$test_dir/live/config.toml"
mkdir -p "$(dirname "$live_config")"

cat >"$base_config" <<'EOF'
model = "tracked-model"

[features]
hooks = true

[otel]
environment = "local"
EOF

cat >"$live_config" <<'EOF'
model = "runtime-model"

[projects."/private/repository"]
trust_level = "trusted"

[hooks.state."generated-hook"]
enabled = true

[runtime_extension]
value = "preserve-me"
EOF

"$sync_script" --base "$base_config" --live "$live_config" >/dev/null

[[ $(yq -p=toml -o=json -r '.model' "$live_config") == "tracked-model" ]] || fail "base value did not win"
[[ $(yq -p=toml -o=json -r '.projects."/private/repository".trust_level' "$live_config") == "trusted" ]] ||
	fail "project state was not preserved"
[[ $(yq -p=toml -o=json -r '.hooks.state."generated-hook".enabled' "$live_config") == "true" ]] ||
	fail "hook state was not preserved"
[[ $(yq -p=toml -o=json -r '.runtime_extension.value' "$live_config") == "preserve-me" ]] ||
	fail "unknown state was not preserved"
[[ -f $live_config.pre-dotfiles ]] || fail "backup was not created"

before_stat=$(stat -c '%i:%Y' "$live_config")
"$sync_script" --base "$base_config" --live "$live_config" >/dev/null
after_stat=$(stat -c '%i:%Y' "$live_config")
[[ $before_stat == "$after_stat" ]] || fail "idempotent sync replaced the live file"

forbidden_base="$test_dir/forbidden.toml"
cat >"$forbidden_base" <<'EOF'
model = "tracked-model"

[projects."/private/repository"]
trust_level = "trusted"
EOF

before_checksum=$(sha256sum "$live_config")
if "$sync_script" --base "$forbidden_base" --live "$live_config" >/dev/null 2>&1; then
	fail "forbidden base was accepted"
fi
after_checksum=$(sha256sum "$live_config")
[[ $before_checksum == "$after_checksum" ]] || fail "forbidden base changed the live file"

invalid_live="$test_dir/invalid.toml"
printf '%s\n' '[broken' >"$invalid_live"
before_checksum=$(sha256sum "$invalid_live")
if "$sync_script" --base "$base_config" --live "$invalid_live" >/dev/null 2>&1; then
	fail "invalid live config was accepted"
fi
after_checksum=$(sha256sum "$invalid_live")
[[ $before_checksum == "$after_checksum" ]] || fail "invalid live config was changed"

bootstrap_live="$test_dir/bootstrap/config.toml"
"$sync_script" --base "$base_config" --live "$bootstrap_live" >/dev/null
[[ $(yq -p=toml -o=json -r '.model' "$bootstrap_live") == "tracked-model" ]] || fail "bootstrap failed"
[[ $(stat -c '%a' "$bootstrap_live") == "600" ]] || fail "bootstrap permissions are not 0600"

check_live="$test_dir/check-only/config.toml"
"$sync_script" --base "$base_config" --live "$check_live" --check >/dev/null
[[ ! -e $(dirname "$check_live") ]] || fail "check mode created the live directory"

dry_run_model=$(
	"$sync_script" --base "$base_config" --live "$live_config" --dry-run |
		yq -p=toml -o=json -r '.model'
)
[[ $dry_run_model == "tracked-model" ]] || fail "dry-run did not print merged TOML"

printf 'test-codex-config-sync: ok\n'
