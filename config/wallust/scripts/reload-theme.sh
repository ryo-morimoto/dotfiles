#!/usr/bin/env bash
set -euo pipefail

# Reload theme after wallust generates new colors
# Called by waypaper's post_command

CACHE_DIR="$HOME/.cache/wallust"
CONFIG_DIR="$HOME/.config"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Concatenate base configs with generated colors
# Mako
if [[ -f "$CONFIG_DIR/mako/base" && -f "$CACHE_DIR/mako-colors.conf" ]]; then
    cat "$CONFIG_DIR/mako/base" "$CACHE_DIR/mako-colors.conf" > "$CONFIG_DIR/mako/config"
fi

# Fuzzel
if [[ -f "$CONFIG_DIR/fuzzel/base" && -f "$CACHE_DIR/fuzzel-colors.ini" ]]; then
    cat "$CONFIG_DIR/fuzzel/base" "$CACHE_DIR/fuzzel-colors.ini" > "$CONFIG_DIR/fuzzel/fuzzel.ini"
fi

# Swaylock
if [[ -f "$CONFIG_DIR/swaylock/base" && -f "$CACHE_DIR/swaylock-colors.conf" ]]; then
    cat "$CONFIG_DIR/swaylock/base" "$CACHE_DIR/swaylock-colors.conf" > "$CONFIG_DIR/swaylock/config"
fi

# Reload mako notifications
pkill -USR2 mako || true

# Reload waybar
pkill -SIGUSR2 waybar || true

# Notify user
notify-send "Theme Updated" "Colors synced from wallpaper" -t 2000
