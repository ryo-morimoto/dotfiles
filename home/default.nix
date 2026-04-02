{
  config,
  lib,
  pkgs,
  dms,
  voxtype,
  ...
}:

let
  dotfilesPath = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles";
  zenBrowserLauncher = pkgs.writeShellScriptBin "zen-browser" ''
    exec ${lib.getExe pkgs.zen-browser} "$@"
  '';
in
{
  imports = [
    ./agents
    ./knowledge
  ];
  home = {
    username = "ryo-morimoto";
    homeDirectory = "/home/ryo-morimoto";
    stateVersion = "25.11";

    sessionVariables = {
      BROWSER = "zen-browser";
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers.override {
        withFirefox = false;
        withWebkit = false;
      }}";
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      CHROME_PATH = lib.getExe pkgs.chromium;
      CLAUDE_CODE_NO_FLICKER = "1";
      CLAUDE_CODE_DISABLE_MOUSE = "1";
    };

    sessionPath = [
      "$HOME/.moon/bin"
      "$HOME/.bun/bin"
    ];

    packages = with pkgs; [
      # Editor
      neovim
      code-cursor

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
      oxfmt
      black
      gofumpt
      stylua

      # Linters (for Neovim)
      nodePackages.eslint
      ruff
      starlint
      semgrep

      # Nix static analysis
      nixf
      flake-checker

      # Terminal
      ghostty

      # Communication
      vesktop
      slack

      # AppImage
      appimage-run

      # CLI tools
      wget
      tree
      ripgrep
      fd
      jq

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
      nvd
      nix-tree
      prek
      gitleaks

      # Development
      ghq
      gh
      git-wt
      pi-coding-agent
      lazygit
      just

      # Web development
      nodejs
      bun
      pnpm
      chromium
      zen-browser
      zenBrowserLauncher

      # System/CLI development
      moonbit-bin.moonbit.latest
      go
      gcc
      rustc
      cargo

      # Shell development
      shellcheck
      shfmt

      # Python
      uv

      # Dev environments
      devbox

      # Container/Infra (docker CLI provided by virtualisation.docker.enable)
      docker-credential-helpers
      kubectl
      k9s

      # Database
      sqlite

      # File operations
      trash-cli
      wtype
      ffmpeg
      imagemagick

      # Utilities
      watchexec
      fastfetch
      age
      libnotify

      # AI tools
      cursor-agent
      seiren-mcp
      vibe-kanban
      claude-squad
      tmuxcc
      beacon
      showboat
      rodney
      agent-browser
      grepika
    ];

    file = {
      ".pi/agent/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/pi/settings.json";
      ".local/bin/beacon-status-popup.sh".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/tmux/beacon-status-popup.sh";
      ".local/bin/beacon-window-jump.sh".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/tmux/beacon-window-jump.sh";
      ".local/bin/beacon-pane-focus.sh".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/tmux/beacon-pane-focus.sh";
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
        credential."https://github.com" = {
          helper = "!\"$HOME/ghq/github.com/ryo-morimoto/dotfiles/tools/gh-router/gh-router\" credential";
          useHttpPath = true;
        };
        merge.conflictstyle = "diff3";
        diff.colorMoved = "default";
        wt = {
          basedir = "../{gitroot}-wt";
          hook = "${dotfilesPath}/scripts/git-wt/on-create.sh";
          deletehook = "${dotfilesPath}/scripts/git-wt/on-delete.sh";
        };
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
            wt = "git wt";
            wtd = "git wt -d";
            wtc = "GIT_WT_AGENT=claude git wt";
            wto = "GIT_WT_AGENT=opencode git wt";
            wtx = "GIT_WT_AGENT=codex git wt";
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
        # GPG
        export GPG_TTY=$(tty)

        # Exa API key (decrypted by agenix)
        [[ -r /run/agenix/exa-api-key ]] && export EXA_API_KEY="$(cat /run/agenix/exa-api-key)"

        # Pencil MCP server path (discovered from AppImage cache)
        [[ -r "$HOME/.cache/pencil-mcp-path" ]] && export PENCIL_MCP_PATH="$(cat "$HOME/.cache/pencil-mcp-path")"

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
      shellWrapperName = "yy";
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

        # Clipboard integration (OSC 52 — works over SSH + local Wayland)
        set -s set-clipboard on
        set -g allow-passthrough on
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

        # tmuxcc agent dashboard popup
        bind a display-popup -E -w 80% -h 80% "tmuxcc || (echo 'tmuxcc failed. Press Enter to close.' && read)"

        # Beacon shortcuts (Ctrl+q b then key)
        bind b switch-client -T beacon
        bind -T beacon s display-popup -E -w 90% -h 80% "bash ~/.local/bin/beacon-status-popup.sh || (echo 'beacon status failed. Press Enter to close.' && read)"
        bind -T beacon w display-popup -E -w 90% -h 80% "bash ~/.local/bin/beacon-window-jump.sh || (echo 'beacon window jump failed. Press Enter to close.' && read)"
        bind -T beacon p display-popup -E -w 90% -h 80% "bash ~/.local/bin/beacon-pane-focus.sh || (echo 'beacon pane focus failed. Press Enter to close.' && read)"
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

    gpg.enable = true;

    password-store = {
      enable = true;
      settings = {
        PASSWORD_STORE_DIR = "$HOME/.password-store";
      };
    };
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 86400;
    maxCacheTtl = 86400;
    pinentry.package = pkgs.pinentry-curses;
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
    gtk4.theme = null;
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
    quickshell.package =
      dms.inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.override
        {
          xorg = pkgs.xorg // {
            inherit (pkgs) libxcb;
          };
        };
    systemd.enable = true;
    niri = {
      enableKeybinds = true;
      enableSpawn = false;
      includes.enable = false;
    };
  };

  # Voxtype voice input (whisper.cpp, Vulkan GPU acceleration)
  programs.voxtype = {
    enable = true;
    engine = "whisper";
    package = voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
    model.name = "large-v3-turbo";
    service.enable = true;
    settings = {
      state_file = "auto";
      hotkey = {
        enabled = true;
        key = "RIGHTCTRL";
        modifiers = [ ];
        mode = "toggle";
      };
      audio = {
        device = "default";
        sample_rate = 16000;
        max_duration_secs = 300;
        feedback = {
          enabled = true;
          theme = "default";
          volume = 0.7;
        };
      };
      whisper = {
        mode = "local";
        model = "large-v3-turbo";
        language = "ja";
        translate = false;
        on_demand_loading = false;
        gpu_isolation = false;
        context_window_optimization = false;
      };
      output = {
        mode = "type";
        fallback_to_clipboard = true;
        type_delay_ms = 0;
        pre_type_delay_ms = 0;
        auto_submit = false;
        paste_keys = "ctrl+v";
        notification = {
          on_recording_start = true;
          on_recording_stop = true;
          on_transcription = true;
        };
      };
    };
  };

  # Voxtype ALSA workaround: voxtype links alsa-lib 1.2.14 (from its flake nixpkgs)
  # but system PipeWire ALSA plugin requires alsa-lib 1.2.15. LD_PRELOAD forces
  # the system alsa-lib so dlopen of the PipeWire plugin succeeds.
  systemd.user.services.voxtype.Service.Environment = [
    "LD_PRELOAD=${pkgs.alsa-lib}/lib/libasound.so.2"
  ];

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
        { proportion = 1.0 / 3.0; }
        { proportion = 1.0 / 2.0; }
        { proportion = 2.0 / 3.0; }
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
      { command = [ "blueman-applet" ]; }
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
            app-id = "(firefox|zen-beta)$";
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

      # Voice input toggle (voxtype)
      "Mod+Shift+V".action.spawn = [
        "voxtype"
        "record"
        "toggle"
      ];

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

      # Float/tile toggle (Mod+V reassigned to voxtype)
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

  home.activation.installBunGlobalPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bun}/bin/bun install -g @tobilu/qmd@2.0.1 2>/dev/null || \
      printf "warning: failed to install qmd via bun\n" >&2
  '';

  xdg = {
    desktopEntries = {
      "zen-browser" = {
        name = "Zen Browser";
        genericName = "Web Browser";
        exec = "zen-browser %U";
        terminal = false;
        icon = "zen-beta";
        categories = [
          "Network"
          "WebBrowser"
        ];
        mimeType = [
          "text/html"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ];
      };
      "pencil-desktop" = {
        name = "Pencil";
        genericName = "Design Tool";
        exec = "appimage-run ${config.home.homeDirectory}/Applications/Pencil.AppImage";
        terminal = false;
        categories = [
          "Graphics"
          "Development"
        ];
      };
    };

    # Default browser associations
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = [ "zen-browser.desktop" ];
        "application/xhtml+xml" = [ "zen-browser.desktop" ];
        "x-scheme-handler/http" = [ "zen-browser.desktop" ];
        "x-scheme-handler/https" = [ "zen-browser.desktop" ];
      };
    };

    # Dotfiles (mkOutOfStoreSymlink for instant updates)
    configFile = {
      "mimeapps.list".force = true;
      "nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/nvim";
      "ghostty".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/ghostty";
      "hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/hypr";
      "zsh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/zsh";
      "wallpaper".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/wallpaper";
      "tmuxcc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/tmuxcc";
      "vde/monitor".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/vde/monitor";
      "lazygit".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/lazygit";
    };
  };
}
