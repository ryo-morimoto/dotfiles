#!/usr/bin/env bash
set -euo pipefail

# Wallust writes the remaining live targets directly (for example ghostty/colors).
# Keep this hook as the wallpaper-picker post-step so the user still gets feedback.
notify-send "Theme Updated" "Colors synced from wallpaper" -t 2000
