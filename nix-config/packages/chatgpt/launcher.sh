#!/usr/bin/env bash
: "${CHATGPT_APP_ROOT:?}"
: "${CHATGPT_VERSION:?}"

src="$CHATGPT_APP_ROOT/resources"
if [[ ! -d "$src/plugins" ]]; then
	echo "ChatGPT plugins directory missing: $src/plugins" >&2
	exit 1
fi

cache_home="${XDG_CACHE_HOME:-${HOME:?HOME is unset}/.cache}"
cache="$cache_home/chatgpt/bundled-plugins/$CHATGPT_VERSION"

# Bundled plugin manifests are rewritten at runtime, so they cannot stay in the
# immutable Nix store. Keep a writable per-version copy and symlink the rest.
if [[ ! -f "$cache/.complete" ]]; then
	mkdir -p "$(dirname "$cache")"
	tmp=$(mktemp -d "$cache.staging.XXXXXX")
	cleanup() { rm -rf "$tmp"; }
	trap cleanup EXIT

	for name in codex codex-code-mode-host cua_node native rg; do
		if [[ -e "$src/$name" ]]; then
			ln -s "$src/$name" "$tmp/$name"
		fi
	done
	cp -R "$src/plugins" "$tmp/plugins"
	chmod -R u+w "$tmp/plugins"
	touch "$tmp/.complete"

	rm -rf "$cache"
	mv "$tmp" "$cache"
	trap - EXIT
fi

export CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH="$cache"

wayland_flags=()
if [[ -z "${CHATGPT_DISABLE_WAYLAND:-}" && -n "${WAYLAND_DISPLAY:-}" ]]; then
	wayland_flags=(
		--ozone-platform=wayland
		--enable-features=WaylandWindowDecorations
		--enable-wayland-ime=true
	)
fi

for arg in "$@"; do
	case "$arg" in
	--ozone-platform=* | --ozone-platform-hint=*)
		wayland_flags=()
		;;
	esac
done

exec "$CHATGPT_APP_ROOT/ChatGPT" "${wayland_flags[@]}" "$@"
