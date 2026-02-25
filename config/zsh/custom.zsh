# Keybindings (Emacs style)
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# OSC 7: notify tmux of CWD for pane splitting
_osc7_precmd() {
  printf '\e]7;file://%s%s\e\\' "${HOST}" "${PWD}"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _osc7_precmd

typeset -g GH_ROUTER_BIN="${HOME}/ghq/github.com/ryo-morimoto/dotfiles/scripts/gh-router"

gh_router_apply_context() {
  [[ -x "$GH_ROUTER_BIN" ]] || return 0

  local exports
  exports="$($GH_ROUTER_BIN apply --shell zsh --cwd "$PWD" 2>/dev/null)" || return 0
  [[ -n "$exports" ]] || return 0

  eval "$exports"
}

gh-router-status() {
  if [[ ! -x "$GH_ROUTER_BIN" ]]; then
    echo "gh-router not found: $GH_ROUTER_BIN" >&2
    return 1
  fi

  "$GH_ROUTER_BIN" status --cwd "$PWD"
}

gh-login() {
  if [[ ! -x "$GH_ROUTER_BIN" ]]; then
    echo "gh-router not found: $GH_ROUTER_BIN" >&2
    return 1
  fi

  "$GH_ROUTER_BIN" login "$@" || return $?
  gh_router_apply_context
}

gh-router-resolve() {
  if [[ ! -x "$GH_ROUTER_BIN" ]]; then
    echo "gh-router not found: $GH_ROUTER_BIN" >&2
    return 1
  fi

  "$GH_ROUTER_BIN" resolve --cwd "$PWD"
}

gh-router-clear-cache() {
  if [[ ! -x "$GH_ROUTER_BIN" ]]; then
    echo "gh-router not found: $GH_ROUTER_BIN" >&2
    return 1
  fi

  "$GH_ROUTER_BIN" clear-cache "$@" || return $?
  gh_router_apply_context
}

add-zsh-hook chpwd gh_router_apply_context
gh_router_apply_context
