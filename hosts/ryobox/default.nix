{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];

  # Bootloader
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Network
  networking = {
    hostName = "ryobox";
    networkmanager.enable = true;
    firewall.interfaces.tailscale0.allowedTCPPorts = [
      80
      443
    ];
  };

  # Locale
  time.timeZone = "Asia/Tokyo";
  i18n = {
    defaultLocale = "ja_JP.UTF-8";
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [ fcitx5-mozc ];
    };
  };
  console = {
    font = "Lat2-Terminus16";
    keyMap = "jp106";
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    hackgen-nf-font
  ];

  # Audio
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
          user = "greeter";
        };
      };
    };
    gnome.gnome-keyring.enable = true;

    # Caddy reverse proxy (TLS via Let's Encrypt DNS-01 + Cloudflare)
    caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
        hash = "sha256-7DGnojZvcQBZ6LEjT0e5O9gZgsvEeHlQP9aKaJIs/Zg=";
      };
      virtualHosts = {
        "vk.ryobox.xyz" = {
          extraConfig = ''
            reverse_proxy localhost:3001
            tls {
              dns cloudflare {env.CLOUDFLARE_API_TOKEN}
            }
          '';
        };
      };
    };

    # Tailscale VPN with SSH
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      extraUpFlags = [ "--ssh" ];
    };

    # OpenSSH disabled - using Tailscale SSH instead
    # openssh = {
    #   enable = true;
    #   openFirewall = false;
    #   settings = {
    #     PermitRootLogin = "no";
    #     PasswordAuthentication = false;
    #   };
    # };
  };

  # agenix: use host SSH key for decryption (openssh is disabled; Tailscale SSH is used instead)
  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      # Caddy: load Cloudflare API token
      caddy-cloudflare = {
        file = ../../secrets/caddy-cloudflare.age;
        owner = "caddy";
        group = "caddy";
        mode = "0400";
      };
      # Exa API key for Claude Code MCP server
      exa-api-key = {
        file = ../../secrets/exa-api-key.age;
        owner = "ryo-morimoto";
        mode = "0400";
      };
    };
  };
  systemd.services = {
    caddy.serviceConfig.EnvironmentFile = config.age.secrets.caddy-cloudflare.path;
    "vibe-kanban" = {
      description = "vibe-kanban service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        HOST = "127.0.0.1";
        PORT = "3001";
        BROWSER = "${pkgs.coreutils}/bin/true";
      };
      serviceConfig = {
        ExecStart = lib.getExe pkgs.vibe-kanban;
        Restart = "on-failure";
        RestartSec = "5s";
        User = "ryo-morimoto";
        WorkingDirectory = "/home/ryo-morimoto";
      };
    };
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Desktop (Niri + DankMaterialShell)
  environment.systemPackages = with pkgs; [
    # Network
    tailscale

    # OSD
    swayosd

    # Wallpaper
    swww

    # Utilities
    wl-clipboard
    pavucontrol
    playerctl
    brightnessctl
  ];

  # XDG Portal
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # Security
  security = {
    polkit.enable = true;
  };

  # Docker
  virtualisation.docker.enable = true;

  # Programs
  programs = {
    niri.enable = true;
    zsh.enable = true;
    firefox.enable = true;
  };

  # User
  users.users.ryo-morimoto = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "docker"
    ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };

  # Claude Code managed settings (immutable — Claude Code never overwrites this)
  # See: https://github.com/anthropics/claude-code/issues/15786
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    permissions.allow = [ "mcp__pencil" ];
    hooks = {
      PostToolUse = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "node ~/.claude/si/scripts/improvement-post-tool.mjs";
              timeout = 3000;
            }
          ];
        }
      ];
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "node ~/.claude/si/scripts/improvement-session-end.mjs";
              timeout = 10000;
            }
          ];
        }
        {
          hooks = [
            {
              type = "command";
              command = "vde-monitor-summary --async Stop -- vde-monitor-hook";
            }
          ];
        }
      ];
      PreCompact = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "node ~/.claude/si/scripts/improvement-pre-compact.mjs";
              timeout = 5000;
            }
          ];
        }
      ];
    };
    statusLine = {
      type = "command";
      command = "node /home/ryo-morimoto/.claude/hud/omc-hud.mjs";
    };
    enabledPlugins = {
      "context7@claude-plugins-official" = true;
      "commit-commands@claude-plugins-official" = true;
      "feature-dev@claude-plugins-official" = true;
      "pr-review-toolkit@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "lua-lsp@claude-plugins-official" = true;
      "code-simplifier@claude-plugins-official" = true;
      "deslop@kuu-marketplace" = true;
      "dig@kuu-marketplace" = true;
      "fix-ci@kuu-marketplace" = true;
      "compound-engineering@every-marketplace" = true;
      "coding-tutor@every-marketplace" = true;
      "decomposition@kuu-marketplace" = true;
      "claude-md-management@claude-plugins-official" = true;
      "skill-creator@claude-plugins-official" = true;
      "coderabbit@claude-plugins-official" = true;
      "semgrep@claude-plugins-official" = true;
      "recore-api-explorer@agent-skills-marketplace" = true;
      "moonbit-practice@moonbit-practice" = true;
      "autofix-bot@claude-plugins-official" = true;
      "data@claude-plugins-official" = true;
      "clangd-lsp@claude-plugins-official" = true;
      "keel@keel" = true;
      # Explicitly disabled
      "superpowers@claude-plugins-official" = false;
      "frontend-design@claude-plugins-official" = false;
      "code-review@claude-plugins-official" = false;
      "security-guidance@claude-plugins-official" = false;
      "ralph-loop@claude-plugins-official" = false;
      "agent-sdk-dev@claude-plugins-official" = false;
      "gopls-lsp@claude-plugins-official" = false;
      "rust-analyzer-lsp@claude-plugins-official" = false;
      "plugin-dev@claude-plugins-official" = false;
    };
    extraKnownMarketplaces = {
      agent-skills-marketplace.source = {
        source = "git";
        url = "https://github.com/commercex-holdings/agent-skills.git";
      };
      moonbit-practice.source = {
        source = "github";
        repo = "mizchi/moonbit-practice";
      };
      keel.source = {
        source = "github";
        repo = "ryo-morimoto/keel";
      };
      kuu-marketplace.source = {
        source = "github";
        repo = "fumiya-kume/claude-code";
      };
      every-marketplace.source = {
        source = "github";
        repo = "EveryInc/compound-engineering-plugin";
      };
    };
    autoUpdatesChannel = "stable";
    minimumVersion = "2.1.12";
    skipDangerousModePermissionPrompt = true;
  };

  # Nix
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
    };

    # Automatic garbage collection (weekly, keep last 7 days)
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    # Automatic store optimization (weekly)
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };
  nixpkgs.config.allowUnfree = true;

  # Allow running dynamically linked binaries (for uv, etc.)
  programs.nix-ld.enable = true;

  system = {
    # /bin/bash symlink (for scripts with #!/bin/bash shebang)
    activationScripts.binbash = ''
      ln -sfn ${pkgs.bash}/bin/bash /bin/bash
    '';

    # Automatic system upgrade (GitOps: pulls from GitHub)
    autoUpgrade = {
      enable = true;
      flake = "github:ryo-morimoto/dotfiles#ryobox";
      dates = "05:00";
      randomizedDelaySec = "45min";
      allowReboot = false;
    };

    stateVersion = "25.11";
  };
}
