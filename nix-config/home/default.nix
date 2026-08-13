{ pkgs, ... }:

let
  coreDevTools = with pkgs; [
    lsof
    openssl
    strace
    tcpdump
    dig
    file
    pciutils
    usbutils
  ];
in
{
  imports = [
    ./agents
    ./desktop
    ./development
    ./knowledge
    ./tmux
    ./zellij
  ];
  home = {
    username = "ryo-morimoto";
    homeDirectory = "/home/ryo-morimoto";
    stateVersion = "25.11";

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.moon/bin"
      "$HOME/.local/share/mise/shims"
      "$HOME/.bun/bin"
    ];

    packages =
      coreDevTools
      ++ (with pkgs; [
        # Editor
        neovim
        code-cursor

        # LSP servers (for Neovim)
        typescript-language-server
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
        eslint
        ruff

        # Nix static analysis
        nixf
        flake-checker

        # Terminal
        ghostty

        # Communication
        vesktop
        slack

        # Design
        penpot-desktop

        # AppImage
        appimage-run

        # CLI tools
        wget
        socat
        tree
        ripgrep
        fd
        jq
        yq-go
        ast-grep
        vhs
        silicon

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
        semgrep
        nvd
        nix-tree
        prek
        gitleaks

        # Development
        ghq
        gh
        git-wt
        worktrunk
        lazygit
        just
        mise
        portless
        nssTools

        # Claude Code sandbox (Linux backend)
        bubblewrap
        socat

        # Web development
        nodejs
        bun
        pnpm
        chromium

        # System/CLI development
        moonbit-bin.moonbit.latest
        go
        gcc
        (fenix.combine [
          (fenix.stable.withComponents [
            "cargo"
            "clippy"
            "rust-src"
            "rustc"
            "rustfmt"
          ])
          fenix.targets.wasm32-unknown-unknown.stable.rust-std
        ])
        wasm-pack

        # Shell development
        shellcheck
        shfmt

        # Python
        python3
        uv

        # Dev environments
        devbox

        # Container/Infra (docker CLI provided by virtualisation.docker.enable)
        docker-credential-helpers
        kubectl
        k9s

        # Google
        google-cloud-sdk
        gws

        # Database
        sqlite

        # File operations
        trash-cli
        wtype
        ffmpeg
        imagemagick

        # Utilities
        _1password-cli
        watchexec
        fastfetch
        age
        libnotify

        # AI tools
        soulforge
        seiren-mcp

        # Dotfiles deployment
        chezmoi
      ]);
  };

  programs = {
    home-manager.enable = true;

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
        # GPG
        export GPG_TTY=$(tty)

        # API keys (decrypted by agenix)
        [[ -r /run/agenix/context7-api-key ]] && export CONTEXT7_API_KEY="$(cat /run/agenix/context7-api-key)"
        [[ -r /run/agenix/exa-api-key ]] && export EXA_API_KEY="$(cat /run/agenix/exa-api-key)"

        # Pencil MCP server path (discovered from AppImage cache)
        [[ -r "$HOME/.cache/pencil-mcp-path" ]] && export PENCIL_MCP_PATH="$(cat "$HOME/.cache/pencil-mcp-path")"

        # Worktrunk shell integration for directory switching.
        eval "$(wt config shell init zsh)"

        # Mise tool shims for non-Nix experimental tools.
        eval "$(mise activate zsh)"

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
      historyWidget.zsh.command = "";
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
      settings = {
        "*" = {
          SetEnv = {
            TERM = "xterm-256color";
          };
        };
        "moon-peak" = {
          HostName = "moon-peak.exe.xyz";
          User = "user";
        };
      };
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
}
