{
  lib,
  pkgs,
  ...
}:

let
  username = "ryo-morimoto";
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/ghq/github.com/${username}/dotfiles";
  agentDefaults = import ../../home/agents/default.nix {
    config = {
      home.homeDirectory = homeDir;
    };
  };
  sharedMcpServers = agentDefaults._module.args.mcpServers;
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
  claudeManagedMcpFile = pkgs.writeText "claude-managed-mcp.json" (
    builtins.toJSON {
      mcpServers = lib.mapAttrs (_: mkClaudeMcp) (
        lib.filterAttrs (_: server: builtins.elem "claude" server.clients) sharedMcpServers
      );
    }
  );
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
      fcitx5 = {
        waylandFrontend = true;
        settings = {
          globalOptions = {
            "Hotkey/TriggerKeys" = {
              "0" = "Control+space";
            };
            "Hotkey/ActivateKeys" = {
              "0" = "Hangul";
            };
            "Hotkey/DeactivateKeys" = {
              "0" = "Hangul_Hanja";
            };
          };
          inputMethod = {
            "Groups/0" = {
              Name = "Default";
              "Default Layout" = "jp";
              DefaultIM = "hazkey";
            };
            "Groups/0/Items/0" = {
              Name = "keyboard-jp";
              Layout = "";
            };
            "Groups/0/Items/1" = {
              Name = "hazkey";
              Layout = "";
            };
            GroupOrder = {
              "0" = "Default";
            };
          };
        };
      };
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
    xserver.xkb = {
      layout = "jp";
      model = "jp106";
    };
    hazkey.enable = true;
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
      # Context7 API key for documentation search
      context7-api-key = {
        file = ../../secrets/context7-api-key.age;
        owner = username;
        mode = "0400";
      };
      # Exa API key for web search
      exa-api-key = {
        file = ../../secrets/exa-api-key.age;
        owner = username;
        mode = "0400";
      };
    };
  };
  systemd.services = {
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
    "claude-code/managed-mcp.json".source = claudeManagedMcpFile;
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

    # Automatic garbage collection (daily, keep last 7 days)
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude"
      "claude-code"
      "coderabbit"
      "cursor"
      "obsidian"
      "slack"
      "soulforge"
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
