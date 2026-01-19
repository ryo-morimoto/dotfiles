{ config, pkgs, ... }:

let
  dotfilesPath = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles";
in {
  home.username = "ryo-morimoto";
  home.homeDirectory = "/home/ryo-morimoto";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # User packages
  home.packages = with pkgs; [
    # Editor
    neovim

    # Terminal
    ghostty

    # CLI tools
    wget
    tree
    ripgrep
    fd

    # Nix tools
    nixfmt
    statix
    deadnix

    # Development
    ghq
    gh
    claude-code
    socat
    bubblewrap

  ];

  # Git
  programs.git = {
    enable = true;
    settings = {
      user.name = "ryo-morimoto";
      user.email = "ryo.morimoto.dev@gmail.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      credential."https://github.com".helper = "!gh auth git-credential";
    };
  };

  # Zsh
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
    };
    shellAliases =
      let
        navigation = {
          ".." = "cd ..";
          "..." = "cd ../..";
        };
        git = {
          g = "git";
          gs = "git status";
          gd = "git diff";
          ga = "git add";
          gc = "git commit";
          gp = "git push";
          gl = "git pull";
        };
        modern = {
          ls = "eza --icons";
          ll = "eza -la --icons";
          la = "eza -a --icons";
          lt = "eza --tree --icons";
          cat = "bat";
          grep = "rg";
          find = "fd";
        };
      in
      navigation // git // modern;
    initContent = ''
      [[ -f ~/.config/zsh/custom.zsh ]] && source ~/.config/zsh/custom.zsh
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Fzf (fuzzy finder)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [ "--height 40%" "--reverse" "--border" ];
  };

  # Eza (modern ls)
  programs.eza = {
    enable = true;
    git = true;
    icons = "auto";
  };

  # Zoxide (smart cd)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Bat (cat with syntax highlighting)
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
    };
  };

  # Direnv (per-directory environment)
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Tmux
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

      # Pane base index
      setw -g pane-base-index 1

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

      # Status bar
      set -g status on
      set -g status-interval 5
      set -g status-position bottom
      set -g status-justify left
      set -g status-style 'bg=#1e1e2e fg=#cdd6f4'

      # Left status - Session name
      set -g status-left-length 50
      set -g status-left '#[fg=#1e1e2e,bg=#89b4fa,bold] #S #[fg=#89b4fa,bg=#1e1e2e] '

      # Right status - Claude Code statusline + time
      set -g status-right-length 120
      set -g status-right '#(cat /tmp/claude-status 2>/dev/null || echo "") #[fg=#cdd6f4]| #[fg=#a6e3a1]#{b:pane_current_path} #[fg=#cdd6f4]| %H:%M '

      # Window status
      setw -g window-status-current-style 'fg=#1e1e2e bg=#f5c2e7 bold'
      setw -g window-status-current-format ' #I:#W#F '
      setw -g window-status-style 'fg=#cdd6f4 bg=#313244'
      setw -g window-status-format ' #I:#W#F '
    '';
  };

  # Dotfiles (mkOutOfStoreSymlink for instant updates)
  xdg.configFile = {
    "ghostty".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/ghostty";
    "niri".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/niri";
    "hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/hypr";
    "zsh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/zsh";
  };

  # Claude Code config (~/.claude is not XDG, so use home.file)
  home.file = {
    ".claude/statusline.sh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/claude/statusline.sh";
    ".claude/settings.local.json".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/claude/settings.local.json";
  };
}
