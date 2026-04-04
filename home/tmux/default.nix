{
  pkgs,
  ...
}:

let
  statusLeft = "#[fg=#1e1e2e,bg=#89b4fa,bold] #S #[fg=#89b4fa,bg=#1e1e2e]";
  statusRight = ''#(cat /tmp/claude-status 2>/dev/null || echo "")#[fg=#a6e3a1]#{b:pane_current_path} #[fg=#cdd6f4]%H:%M'';
  beaconPopup =
    command: fallback:
    ''display-popup -E -w 90% -h 80% "${command} || (echo '${fallback}. Press Enter to close.' && read)"'';
in
{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 0;
    historyLimit = 50000;
    mouse = true;
    baseIndex = 1;
    keyMode = "vi";
    prefix = "C-q";
    extraConfig = ''
      # Terminal overrides
      set -ag terminal-overrides ",xterm-256color:RGB"
      set -ag terminal-overrides ",ghostty:RGB"

      # Clipboard integration (OSC 52 -- works over SSH + local Wayland)
      # Keep passthrough off because some interactive TUIs can read terminal
      # control responses as input when tmux forwards them.
      set -s set-clipboard on
      set -g allow-passthrough off
      set -ag terminal-overrides ",*:Ms=\\E]52;c;%p2%s\\7"

      # Copy: OSC 52 (always via set-clipboard on) + wl-copy (local only, silent fail over SSH)
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy 2>/dev/null || true"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy 2>/dev/null || true"
      bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy 2>/dev/null || true"

      # Paste: wl-paste (local) / tmux buffer fallback (SSH)
      bind v run "wl-paste -n 2>/dev/null | tmux load-buffer - ; tmux paste-buffer"
      bind -n MouseDown3Pane run "wl-paste -n 2>/dev/null | tmux load-buffer - ; tmux paste-buffer"

      # Pane base index
      setw -g pane-base-index 1

      # Pane border title (shows haiku from Claude Code Stop hook)
      set -g pane-border-status top
      set -g pane-border-format " #{pane_index}: #{?pane_title,#{pane_title},#{pane_current_command}} "
      set -g pane-border-style "fg=#585b70"
      set -g pane-active-border-style "fg=#89b4fa"

      # Split panes
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Vim-like pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Beacon shortcuts (Ctrl+q b then key)
      bind b switch-client -T beacon
      bind -T beacon s ${beaconPopup "bash ~/.local/bin/beacon-status-popup.sh" "beacon status failed"}
      bind -T beacon w ${beaconPopup "bash ~/.local/bin/beacon-window-jump.sh" "beacon window jump failed"}
      bind -T beacon p ${beaconPopup "bash ~/.local/bin/beacon-pane-focus.sh" "beacon pane focus failed"}
      bind -T beacon c run-shell "beacon clean >/dev/null 2>&1"
      bind -T beacon q switch-client -T prefix
      bind -T beacon Escape switch-client -T prefix

      # Status bar
      set -g status on
      set -g status-interval 5
      set -g status-position bottom
      set -g status-justify left
      set -g status-style 'bg=#1e1e2e fg=#cdd6f4'

      # Left status - Session name
      set -g status-left-length 30
      set -g status-left '${statusLeft}'

      # Right status - preserve continuum's autosave interpolation
      set -g status-right-length 100
      set -ag status-right '${statusRight}'

      # Window status
      setw -g window-status-current-style 'fg=#1e1e2e bg=#f5c2e7 bold'
      setw -g window-status-current-format ' #I:#W '
      setw -g window-status-style 'fg=#cdd6f4 bg=#313244'
      setw -g window-status-format ' #I:#W '
    '';
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-processes 'false'
          # Strip Nix store paths so restore works after nixos-rebuild
          set -g @resurrect-hook-post-save-all 'target=$(readlink -f $HOME/.tmux/resurrect/last); sed -i "s| --cmd .*-vim-pack-dir||g; s|/etc/profiles/per-user/$USER/bin/||g; s|/home/$USER/.nix-profile/bin/||g" $target'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];
  };
}
