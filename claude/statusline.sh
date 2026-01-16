#!/bin/bash
# ccstatusline - Claude Code statusline
# Style: Simple and understated, starship/zsh inspired

set -e

# ANSI color codes
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'

# Read JSON input from stdin
input=$(cat)

# Parse JSON with jq
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
context_percent=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

# Get directory name (basename)
dir_name="${cwd##*/}"
[ -z "$dir_name" ] && dir_name="~"

# Get git branch (if in a git repo)
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    [ -n "$branch" ] && git_branch=" 🌿 $branch"
fi

# Format cost (show only if > 0)
cost_str=""
if [ "$(echo "$cost > 0" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    cost_str=$(printf " ${GRAY}|${RESET} ${YELLOW}\$%.2f${RESET}" "$cost")
fi

# Context color based on usage
context_color="$GREEN"
ctx_int=${context_percent%.*}
[ "$ctx_int" -ge 50 ] && context_color="$YELLOW"
[ "$ctx_int" -ge 80 ] && context_color="$RED"

# Build statusline
# Format: [Model] dir 🌿 branch | $0.00 | 42%
printf "${CYAN}${BOLD}[%s]${RESET} %s${GREEN}%s${RESET}%s ${GRAY}|${RESET} ${context_color}%d%%${RESET}\n" \
    "$model" \
    "$dir_name" \
    "$git_branch" \
    "$cost_str" \
    "${ctx_int:-0}"
