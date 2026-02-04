# キーバインド (Emacs style)
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# OSC 7: tmux に CWD を通知する（tmux-ssh-split の CWD 引き継ぎに必要）
_osc7_precmd() {
  printf '\e]7;file://%s%s\e\\' "${HOST}" "${PWD}"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _osc7_precmd
