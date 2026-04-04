{
  config,
  lib,
  pkgs,
  ...
}:

let
  username = "ryo-morimoto";
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/ghq/github.com/${username}/dotfiles";
  agentPolicy = import ../../home/agents/policy.nix {
    config = {
      home.homeDirectory = homeDir;
    };
  };
  sharedAgentPolicy = agentPolicy.agentPolicyData;
  mkClaudeMcp =
    server:
    if server.transport == "stdio" then
      {
        type = "stdio";
        inherit (server) command args;
      }
    else
      {
        type = "http";
        inherit (server) url;
      };
  mkCodexRequirementMcp =
    server:
    if server.transport == "stdio" then
      {
        identity.command = server.command;
      }
    else
      {
        identity.url = server.url;
      };
  claudeManagedSettings = {
    permissions = {
      allow = [
        "Bash(git status*)"
        "Bash(git diff*)"
        "Bash(git log*)"
        "Bash(nixfmt *)"
        "Bash(nix flake check*)"
      ];
      deny = agentPolicy.dangerousBashPatterns ++ agentPolicy.secretPathRules;
      disableBypassPermissionsMode = "disable";
    };
    allowManagedPermissionRulesOnly = true;
    allowManagedMcpServersOnly = true;
    sandbox = {
      enabled = true;
      autoAllowBashIfSandboxed = false;
      filesystem = {
        allowManagedReadPathsOnly = true;
        read = agentPolicy.trustedReadPaths;
        write = agentPolicy.trustedWritePaths;
      };
      network = {
        allowManagedDomainsOnly = true;
        allowedDomains = agentPolicy.trustedHttpDomains;
      };
    };
  };
  claudeManagedSettingsFile = pkgs.writeText "claude-managed-settings.json" (
    builtins.toJSON claudeManagedSettings
  );
  claudeManagedMcpFile = pkgs.writeText "claude-managed-mcp.json" (
    builtins.toJSON {
      mcpServers = lib.mapAttrs (_: mkClaudeMcp) (
        lib.filterAttrs (_: server: builtins.elem "claude" server.clients) sharedAgentPolicy.mcpServers
      );
    }
  );
  codexRequirementsFile = (pkgs.formats.toml { }).generate "codex-requirements.toml" {
    allowed_approval_policies = sharedAgentPolicy.runtime.allowedApprovalPolicies;
    allowed_sandbox_modes = sharedAgentPolicy.runtime.allowedSandboxModes;
    allowed_web_search_modes = sharedAgentPolicy.runtime.allowedWebSearchModes;
    rules.prefix_rules = sharedAgentPolicy.runtime.prefixRules;
    mcp_servers = lib.mapAttrs (_: mkCodexRequirementMcp) (
      lib.filterAttrs (_: server: builtins.elem "codex" server.clients) sharedAgentPolicy.mcpServers
    );
  };
  codexManagedConfigFile = (pkgs.formats.toml { }).generate "codex-managed-config.toml" {
    approval_policy = sharedAgentPolicy.runtime.approvalPolicy;
    sandbox_mode = sharedAgentPolicy.runtime.sandboxMode;
    sandbox_workspace_write.network_access = sharedAgentPolicy.runtime.sandboxNetworkAccess;
    otel.log_user_prompt = sharedAgentPolicy.runtime.logUserPrompt;
  };
in
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
        owner = username;
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
        User = username;
        WorkingDirectory = homeDir;
      };
    };
    "dotfiles-pull" = {
      description = "Pull latest dotfiles from GitHub";
      serviceConfig = {
        Type = "oneshot";
        User = username;
        WorkingDirectory = dotfilesDir;
        ExecStart = "${pkgs.git}/bin/git pull --ff-only";
      };
    };
    "nixos-upgrade" = {
      after = [ "dotfiles-pull.service" ];
      wants = [ "dotfiles-pull.service" ];
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
    awww

    # Utilities
    wl-clipboard
    pavucontrol
    playerctl
    brightnessctl
  ];

  environment.etc = {
    "claude-code/managed-settings.json".source = claudeManagedSettingsFile;
    "claude-code/managed-mcp.json".source = claudeManagedMcpFile;
    "codex/requirements.toml".source = codexRequirementsFile;
    "codex/managed_config.toml".source = codexManagedConfigFile;
  };

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
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "docker"
      "input"
    ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
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

    # Automatic garbage collection (weekly, keep last 3 days)
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
    };
  };
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude"
      "claude-code"
      "cursor"
      "obsidian"
      "slack"
    ];

  # Allow running dynamically linked binaries (for uv, etc.)
  programs.nix-ld.enable = true;

  system = {
    # /bin/bash symlink (for scripts with #!/bin/bash shebang)
    activationScripts.binbash = ''
      ln -sfn ${pkgs.bash}/bin/bash /bin/bash
    '';

    # Automatic system upgrade from local repo (git pull → rebuild)
    autoUpgrade = {
      enable = true;
      flake = "${dotfilesDir}#ryobox";
      dates = "05:00";
      randomizedDelaySec = "45min";
      allowReboot = false;
    };

    stateVersion = "25.11";
  };
}
