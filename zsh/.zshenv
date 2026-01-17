# XDG Base Directory
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Zsh config directory
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Claude Code
export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"

# PATH
typeset -U path
path=(
    "$HOME/.local/bin"
    "$HOME/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    $path
)
