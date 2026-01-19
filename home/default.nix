{ config, pkgs, ... }:

let
  dotfilesPath = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles";
in
{
  home = {
    username = "ryo-morimoto";
    homeDirectory = "/home/ryo-morimoto";
    stateVersion = "25.11";

    packages = with pkgs; [
      # Editor
      neovim

      # Terminal
      ghostty

      # CLI tools
      wget
      tree
      ripgrep
      fd
      jq
      yq-go
      httpie
      tokei

      # Modern CLI replacements
      btop
      procs
      duf
      dust
      sd
      difftastic
      hyperfine
      glow
      ouch
      bandwhich
      navi

      # Nix tools
      nixfmt
      statix
      deadnix

      # Development
      ghq
      gh
      claude-code
      codex
      socat
      bubblewrap
      lazygit
      just

      # Web development
      nodejs
      bun
      pnpm

      # System/CLI development
      go
      rustc
      cargo
      mold

      # Shell development
      shellcheck
      shfmt

      # Container/Infra
      docker
      dive
      kubectl
      k9s

      # Database
      sqlite
      usql

      # File operations
      trash-cli
      wl-clipboard
      ffmpeg
      imagemagick
      pandoc

      # Utilities
      watchexec
      fastfetch
      age
    ];

    file = {
      ".claude/statusline.sh".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/claude/statusline.sh";
      ".claude/settings.local.json".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/claude/settings.local.json";
    };
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      settings = {
        user.name = "ryo-morimoto";
        user.email = "ryo.morimoto.dev@gmail.com";
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        credential."https://github.com".helper = "!gh auth git-credential";
        merge.conflictstyle = "diff3";
        diff.colorMoved = "default";
      };
    };

    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };

    zsh = {
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
      historySubstringSearch = {
        enable = true;
        searchUpKey = [
          "^[[A"
          "$terminfo[kcuu1]"
        ];
        searchDownKey = [
          "^[[B"
          "$terminfo[kcud1]"
        ];
      };
      plugins = [
        {
          name = "fzf-tab";
          src = pkgs.zsh-fzf-tab;
          file = "share/fzf-tab/fzf-tab.plugin.zsh";
        }
        {
          name = "zsh-autopair";
          src = pkgs.zsh-autopair;
          file = "share/zsh/zsh-autopair/autopair.zsh";
        }
      ];
      shellAliases =
        let
          navigation = {
            ".." = "cd ..";
            "..." = "cd ../..";
            "...." = "cd ../../..";
            take = "mkdir -p $1 && cd $1";
          };
          git = {
            g = "git";
            gs = "git status";
            gd = "git diff";
            ga = "git add";
            gc = "git commit";
            gp = "git push";
            gl = "git pull";
            gco = "git checkout";
            gcb = "git checkout -b";
            lg = "lazygit";
          };
          modern = {
            ls = "eza --icons";
            ll = "eza -la --icons";
            la = "eza -a --icons";
            lt = "eza --tree --icons";
            cat = "bat";
            grep = "rg";
            find = "fd";
            ps = "procs";
            du = "dust";
            df = "duf";
            top = "btop";
            sed = "sd";
            diff = "difftastic";
          };
          utils = {
            path = "echo $PATH | tr ':' '\\n'";
            ports = "ss -tulanp";
            myip = "curl -s ifconfig.me";
            rm = "trash";
            cp = "cp -iv";
            mv = "mv -iv";
            clip = "wl-copy";
            paste = "wl-paste";
          };
          k8s = {
            k = "kubectl";
            kx = "kubectx";
            kn = "kubens";
          };
        in
        navigation // git // modern // utils // k8s;
      initContent = ''
        # Shell options
        setopt AUTO_CD              # cd by typing directory name
        setopt AUTO_PUSHD           # Push to directory stack on cd
        setopt PUSHD_IGNORE_DUPS    # No duplicates in dir stack
        setopt PUSHD_SILENT         # Silent pushd
        setopt CORRECT              # Command correction
        setopt CDABLE_VARS          # cd to named directories
        setopt EXTENDED_GLOB        # Extended globbing
        setopt GLOB_DOTS            # Match dotfiles with *

        # fzf-tab configuration
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
        zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --color=always --style=numbers --line-range=:500 $realpath 2>/dev/null || eza -1 --color=always $realpath 2>/dev/null || echo $realpath'
        zstyle ':fzf-tab:*' fzf-flags --height=50%

        # Double ESC to add sudo
        sudo-command-line() {
          [[ -z $BUFFER ]] && zle up-history
          if [[ $BUFFER == sudo\ * ]]; then
            LBUFFER="''${LBUFFER#sudo }"
          else
            LBUFFER="sudo $LBUFFER"
          fi
        }
        zle -N sudo-command-line
        bindkey '\e\e' sudo-command-line

        # ghq + fzf integration (Ctrl+g)
        ghq-fzf() {
          local repo=$(ghq list | fzf --preview "eza --tree --level=1 --color=always $(ghq root)/{}" --height=50%)
          if [[ -n "$repo" ]]; then
            cd "$(ghq root)/$repo"
            zle reset-prompt
          fi
        }
        zle -N ghq-fzf
        bindkey '^g' ghq-fzf

        # Extract function - universal archive extractor
        extract() {
          if [[ -f $1 ]]; then
            case $1 in
              *.tar.bz2)   tar xjf $1    ;;
              *.tar.gz)    tar xzf $1    ;;
              *.tar.xz)    tar xJf $1    ;;
              *.bz2)       bunzip2 $1    ;;
              *.rar)       unrar x $1    ;;
              *.gz)        gunzip $1     ;;
              *.tar)       tar xf $1     ;;
              *.tbz2)      tar xjf $1    ;;
              *.tgz)       tar xzf $1    ;;
              *.zip)       unzip $1      ;;
              *.Z)         uncompress $1 ;;
              *.7z)        7z x $1       ;;
              *.zst)       unzstd $1     ;;
              *)           echo "'$1' cannot be extracted" ;;
            esac
          else
            echo "'$1' is not a valid file"
          fi
        }

        # mkcd - make directory and cd into it
        mkcd() {
          mkdir -p "$1" && cd "$1"
        }

        # Custom config
        [[ -f ~/.config/zsh/custom.zsh ]] && source ~/.config/zsh/custom.zsh
      '';
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultOptions = [
        "--height 40%"
        "--reverse"
        "--border"
      ];
    };

    eza = {
      enable = true;
      git = true;
      icons = "auto";
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
      };
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        auto_sync = false;
        update_check = false;
        style = "compact";
        inline_height = 20;
      };
    };

    tealdeer = {
      enable = true;
      settings = {
        updates = {
          auto_update = true;
        };
      };
    };

    yazi = {
      enable = true;
      enableZshIntegration = true;
    };

    tmux = {
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
  };

  # GTK theme (Catppuccin Mocha)
  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-lavender-standard+default";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "lavender" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "catppuccin-mocha-lavender-cursors";
      package = pkgs.catppuccin-cursors.mochaLavender;
      size = 24;
    };
  };

  # Dotfiles (mkOutOfStoreSymlink for instant updates)
  xdg.configFile = {
    "ghostty".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/ghostty";
    "niri".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/niri";
    "hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/hypr";
    "zsh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/zsh";
    "waybar".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/waybar";
    "fuzzel".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/fuzzel";
    "mako".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/mako";
  };
}
