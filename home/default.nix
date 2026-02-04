{
  config,
  pkgs,
  ...
}:

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

      # LSP servers (for Neovim)
      nodePackages.typescript-language-server
      vscode-langservers-extracted
      pyright
      rust-analyzer
      gopls
      lua-language-server
      nixd
      tailwindcss-language-server

      # Formatters (for Neovim)
      prettierd
      black
      gofumpt
      stylua

      # Linters (for Neovim)
      nodePackages.eslint
      ruff

      # Terminal
      ghostty

      # Communication
      vesktop

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
      ralph-tui
      socat
      bubblewrap
      lazygit
      just

      # Web development
      nodejs
      bun
      pnpm
      chromium

      # System/CLI development
      go
      rustc
      cargo
      mold

      # Shell development
      shellcheck
      shfmt

      # Python
      uv

      # Dev environments
      devbox

      # Container/Infra
      docker
      dive
      kubectl
      k9s

      # Database
      sqlite
      usql
      turso-cli

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

      # AI tools
      vibe-kanban
      claude-squad
      tmuxcc
    ];

    file = {
      ".claude/CLAUDE.md".text =
        builtins.readFile ../config/claude/CLAUDE.md + builtins.readFile ../config/claude/CLAUDE.md.tmpl;
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

        # Playwright configuration (use system Chromium)
        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
        export CHROME_PATH="$(which chromium 2>/dev/null)"

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

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          setEnv = {
            TERM = "xterm-256color";
          };
        };
        "moon-peak" = {
          hostname = "moon-peak.exe.xyz";
          user = "user";
        };
      };
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

        # Clipboard integration (Wayland)
        set -s set-clipboard on
        set -ag terminal-overrides ",ghostty:clipboard"

        # Mouse drag auto-copy
        bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy"
        bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy"

        # Easy paste: Ctrl+q v or right-click
        bind v run "wl-paste -n | tmux load-buffer - ; tmux paste-buffer"
        bind -n MouseDown3Pane run "wl-paste -n | tmux load-buffer - ; tmux paste-buffer"

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

        # tmuxcc agent dashboard popup
        bind a display-popup -E -w 80% -h 80% "tmuxcc || (echo 'tmuxcc failed. Press Enter to close.' && read)"

        # Status bar
        set -g status on
        set -g status-interval 5
        set -g status-position bottom
        set -g status-justify left
        set -g status-style 'bg=#1e1e2e fg=#cdd6f4'

        # Left status - Session name
        set -g status-left-length 30
        set -g status-left '#[fg=#1e1e2e,bg=#89b4fa,bold] #S #[fg=#89b4fa,bg=#1e1e2e]'

        # Right status - Claude Code statusline + time
        set -g status-right-length 100
        set -g status-right '#(cat /tmp/claude-status 2>/dev/null || echo "")#[fg=#a6e3a1]#{b:pane_current_path} #[fg=#cdd6f4]%H:%M'

        # Window status
        setw -g window-status-current-style 'fg=#1e1e2e bg=#f5c2e7 bold'
        setw -g window-status-current-format ' #I:#W '
        setw -g window-status-style 'fg=#cdd6f4 bg=#313244'
        setw -g window-status-format ' #I:#W '
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

  # System color scheme (for apps that detect light/dark mode)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  # DankMaterialShell (desktop shell replacing waybar, mako, fuzzel, swaylock)
  programs.dank-material-shell = {
    enable = true;
    enableDynamicTheming = true;
    enableClipboardPaste = true;
    enableSystemMonitoring = true;
    systemd.enable = false;
    niri = {
      enableKeybinds = true;
      enableSpawn = true;
      includes.enable = false;
    };
  };

  # Niri compositor (managed by niri-flake, DMS merges keybinds/spawn into settings)
  programs.niri.package = pkgs.niri;
  programs.niri.settings = {
    input = {
      keyboard = {
        xkb.layout = "jp";
        numlock = true;
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
      };
    };

    outputs."HDMI-A-2".mode = {
      width = 1920;
      height = 1080;
      refresh = 143.981;
    };

    layout = {
      gaps = 6;
      center-focused-column = "never";
      preset-column-widths = [
        { proportion = 1. / 3.; }
        { proportion = 1. / 2.; }
        { proportion = 2. / 3.; }
      ];
      default-column-width = {
        proportion = 0.5;
      };
      focus-ring = {
        width = 2;
        active.gradient = {
          from = "#957fb8";
          to = "#7e9cd8";
          angle = 45;
        };
        inactive.color = "#363646";
      };
      border.enable = false;
      shadow.enable = false;
    };

    spawn-at-startup = [
      { command = [ "swww-daemon" ]; }
      { command = [ "swayosd-server" ]; }
    ];

    prefer-no-csd = true;
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    window-rules = [
      {
        matches = [
          { app-id = "^org\\.wezfurlong\\.wezterm$"; }
        ];
        default-column-width = { };
      }
      {
        matches = [
          {
            app-id = "firefox$";
            title = "^Picture-in-Picture$";
          }
        ];
        open-floating = true;
      }
      {
        geometry-corner-radius =
          let
            r = 4.0;
          in
          {
            top-left = r;
            top-right = r;
            bottom-left = r;
            bottom-right = r;
          };
        clip-to-geometry = true;
      }
    ];

    binds = {
      "Mod+Shift+Slash".action.show-hotkey-overlay = { };

      # Applications
      "Mod+T".action.spawn = "ghostty";

      # System controls (DMS handles launcher, notifications, lock, power menu)
      "Mod+A".action.spawn = "pavucontrol";
      "Mod+Shift+N".action.spawn = [
        "ghostty"
        "-e"
        "nmtui"
      ];

      # Volume controls with SwayOSD (for keyboards without media keys)
      "Mod+F1".action.spawn = [
        "swayosd-client"
        "--output-volume"
        "mute-toggle"
      ];
      "Mod+F2".action.spawn = [
        "swayosd-client"
        "--output-volume"
        "lower"
      ];
      "Mod+F3".action.spawn = [
        "swayosd-client"
        "--output-volume"
        "raise"
      ];

      # Media player controls (DMS handles XF86 volume/brightness keys)
      "XF86AudioPlay".action.spawn = [
        "playerctl"
        "play-pause"
      ];
      "XF86AudioStop".action.spawn = [
        "playerctl"
        "stop"
      ];
      "XF86AudioPrev".action.spawn = [
        "playerctl"
        "previous"
      ];
      "XF86AudioNext".action.spawn = [
        "playerctl"
        "next"
      ];

      # Window operations
      "Mod+Q".action.close-window = { };
      "Mod+O".action.toggle-overview = { };

      # Focus navigation
      "Mod+Left".action.focus-column-left = { };
      "Mod+Down".action.focus-window-down = { };
      "Mod+Up".action.focus-window-up = { };
      "Mod+Right".action.focus-column-right = { };
      "Mod+H".action.focus-column-left = { };
      "Mod+J".action.focus-window-down = { };
      "Mod+K".action.focus-window-up = { };
      "Mod+L".action.focus-column-right = { };

      # Move columns/windows
      "Mod+Ctrl+Left".action.move-column-left = { };
      "Mod+Ctrl+Down".action.move-window-down = { };
      "Mod+Ctrl+Up".action.move-window-up = { };
      "Mod+Ctrl+Right".action.move-column-right = { };
      "Mod+Ctrl+H".action.move-column-left = { };
      "Mod+Ctrl+J".action.move-window-down = { };
      "Mod+Ctrl+K".action.move-window-up = { };
      "Mod+Ctrl+L".action.move-column-right = { };

      "Mod+Home".action.focus-column-first = { };
      "Mod+End".action.focus-column-last = { };
      "Mod+Ctrl+Home".action.move-column-to-first = { };
      "Mod+Ctrl+End".action.move-column-to-last = { };

      # Monitor focus
      "Mod+Shift+Left".action.focus-monitor-left = { };
      "Mod+Shift+Down".action.focus-monitor-down = { };
      "Mod+Shift+Up".action.focus-monitor-up = { };
      "Mod+Shift+Right".action.focus-monitor-right = { };
      "Mod+Shift+H".action.focus-monitor-left = { };
      "Mod+Shift+J".action.focus-monitor-down = { };
      "Mod+Shift+K".action.focus-monitor-up = { };
      "Mod+Shift+L".action.focus-monitor-right = { };

      # Move to monitor
      "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = { };
      "Mod+Shift+Ctrl+Down".action.move-column-to-monitor-down = { };
      "Mod+Shift+Ctrl+Up".action.move-column-to-monitor-up = { };
      "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = { };
      "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = { };
      "Mod+Shift+Ctrl+J".action.move-column-to-monitor-down = { };
      "Mod+Shift+Ctrl+K".action.move-column-to-monitor-up = { };
      "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = { };

      # Workspaces
      "Mod+Page_Down".action.focus-workspace-down = { };
      "Mod+Page_Up".action.focus-workspace-up = { };
      "Mod+U".action.focus-workspace-down = { };
      "Mod+I".action.focus-workspace-up = { };
      "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = { };
      "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = { };
      "Mod+Ctrl+U".action.move-column-to-workspace-down = { };
      "Mod+Ctrl+I".action.move-column-to-workspace-up = { };

      "Mod+Shift+Page_Down".action.move-workspace-down = { };
      "Mod+Shift+Page_Up".action.move-workspace-up = { };
      "Mod+Shift+U".action.move-workspace-down = { };
      "Mod+Shift+I".action.move-workspace-up = { };

      # Mouse wheel
      "Mod+WheelScrollDown" = {
        cooldown-ms = 150;
        action.focus-workspace-down = { };
      };
      "Mod+WheelScrollUp" = {
        cooldown-ms = 150;
        action.focus-workspace-up = { };
      };
      "Mod+Ctrl+WheelScrollDown" = {
        cooldown-ms = 150;
        action.move-column-to-workspace-down = { };
      };
      "Mod+Ctrl+WheelScrollUp" = {
        cooldown-ms = 150;
        action.move-column-to-workspace-up = { };
      };

      "Mod+WheelScrollRight".action.focus-column-right = { };
      "Mod+WheelScrollLeft".action.focus-column-left = { };
      "Mod+Ctrl+WheelScrollRight".action.move-column-right = { };
      "Mod+Ctrl+WheelScrollLeft".action.move-column-left = { };

      "Mod+Shift+WheelScrollDown".action.focus-column-right = { };
      "Mod+Shift+WheelScrollUp".action.focus-column-left = { };
      "Mod+Ctrl+Shift+WheelScrollDown".action.move-column-right = { };
      "Mod+Ctrl+Shift+WheelScrollUp".action.move-column-left = { };

      # Workspace by index
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;
      "Mod+Ctrl+1".action.move-column-to-workspace = 1;
      "Mod+Ctrl+2".action.move-column-to-workspace = 2;
      "Mod+Ctrl+3".action.move-column-to-workspace = 3;
      "Mod+Ctrl+4".action.move-column-to-workspace = 4;
      "Mod+Ctrl+5".action.move-column-to-workspace = 5;
      "Mod+Ctrl+6".action.move-column-to-workspace = 6;
      "Mod+Ctrl+7".action.move-column-to-workspace = 7;
      "Mod+Ctrl+8".action.move-column-to-workspace = 8;
      "Mod+Ctrl+9".action.move-column-to-workspace = 9;

      # Column operations
      "Mod+BracketLeft".action.consume-or-expel-window-left = { };
      "Mod+BracketRight".action.consume-or-expel-window-right = { };
      "Mod+Y".action.consume-window-into-column = { };
      "Mod+Period".action.expel-window-from-column = { };

      # Window sizing
      "Mod+R".action.switch-preset-column-width = { };
      "Mod+Shift+R".action.switch-preset-window-height = { };
      "Mod+Ctrl+R".action.reset-window-height = { };
      "Mod+F".action.maximize-column = { };
      "Mod+Shift+F".action.fullscreen-window = { };
      "Mod+Ctrl+F".action.expand-column-to-available-width = { };
      "Mod+C".action.center-column = { };
      "Mod+Ctrl+C".action.center-visible-columns = { };

      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+Equal".action.set-column-width = "+10%";
      "Mod+Shift+Minus".action.set-window-height = "-10%";
      "Mod+Shift+Equal".action.set-window-height = "+10%";

      # Float/tile toggle (Mod+V is used by DMS clipboard)
      "Mod+G".action.toggle-window-floating = { };
      "Mod+Shift+G".action.switch-focus-between-floating-and-tiling = { };

      # Tabbed column display
      "Mod+W".action.toggle-column-tabbed-display = { };

      # Screenshot
      "Mod+Shift+S".action.screenshot = { };
      "Mod+Shift+Ctrl+S".action.screenshot-screen = { };
      "Mod+Shift+Alt+S".action.screenshot-window = { };

      # Keyboard shortcuts inhibit
      "Mod+Escape" = {
        allow-inhibiting = false;
        action.toggle-keyboard-shortcuts-inhibit = { };
      };

      # Quit niri
      "Mod+Shift+E".action.quit = { };
      "Ctrl+Alt+Delete".action.quit = { };

      # Power off monitors
      "Mod+Shift+P".action.power-off-monitors = { };
    };
  };

  # Dotfiles (mkOutOfStoreSymlink for instant updates)
  xdg.configFile = {
    "nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/nvim";
    "ghostty".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/ghostty";
    "hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/hypr";
    "zsh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/zsh";
    "wallpaper".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/wallpaper";
    "tmuxcc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/tmuxcc";
  };
}
