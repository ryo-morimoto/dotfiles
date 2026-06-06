{
  agenix,
  config,
  lib,
  pkgs,
  ...
}:

let
  username = "ryo-morimoto";
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/ghq/github.com/${username}/dotfiles";
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    ./hardware-configuration.nix
    ./forgejo.nix
    ./plane.nix
  ];

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
      5757
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
              "1" = "Zenkaku_Hankaku";
            };
            "Hotkey/ActivateKeys" = {
              "0" = "Hiragana_Katakana";
            };
            "Hotkey/DeactivateKeys" = {
              "0" = "Eisu_toggle";
              "1" = "Muhenkan";
              "2" = "Hangul_Hanja";
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

    # Caddy reverse proxy (tailnet-only via caddy-tailscale; TLS via Tailscale cert)
    caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.2"
          "github.com/tailscale/caddy-tailscale@v0.0.0-20260106222316-bb080c4414ac"
        ];
        hash = "sha256-Rf7afAqQUYHTkB3TH9yly7eMaScc15fmg+6FcajLR8A=";
      };
      globalConfig = ''
        tailscale {
          auth_key {env.TS_AUTHKEY}
          default {
            state_dir /var/lib/caddy/tsnet
            tags tag:caddy
          }
          git {
            hostname git
          }
          plane {
            hostname plane
          }
        }
      '';
      virtualHosts = {
        "https://git.tail9f641.ts.net" = {
          extraConfig = ''
            bind tailscale/git
            reverse_proxy 127.0.0.1:3000
          '';
        };
        "https://plane.tail9f641.ts.net" = {
          extraConfig = ''
            bind tailscale/plane
            reverse_proxy 127.0.0.1:8090
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

  systemd.user.services.hazkey-server.serviceConfig.WorkingDirectory = "%t";

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
      # Caddy: Tailscale OAuth client secret for caddy-tailscale plugin tsnet nodes
      caddy-tailscale-oauth = {
        file = ../../secrets/caddy-tailscale-oauth.age;
        owner = "caddy";
        group = "caddy";
        mode = "0400";
      };
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
    caddy.serviceConfig.EnvironmentFile = [
      config.age.secrets.caddy-cloudflare.path
      config.age.secrets.caddy-tailscale-oauth.path
    ];

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
    agenix.packages.${system}.default
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

  # Containers
  virtualisation = {
    containers.enable = true;
    docker.enable = true;
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

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
      extra-substituters = [
        "https://cache.numtide.com"
        "https://codex-cli.cachix.org"
      ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing="
      ];
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
      "cursor"
      "obsidian"
      "slack"
      "soulforge"
    ];

  # Allow running dynamically linked binaries (for uv, mise-installed zed, etc.)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      libGL
      vulkan-loader
      fontconfig
      wayland
      libxkbcommon
    ];
  };

  system = {
    # /bin/bash symlink (for scripts with #!/bin/bash shebang)
    activationScripts.binbash = ''
      ln -sfn ${pkgs.bash}/bin/bash /bin/bash
    '';

    # Automatic system upgrade from local repo (git pull → rebuild)
    autoUpgrade = {
      enable = true;
      flake = "${dotfilesDir}/nix-config#ryobox";
      dates = "05:00";
      randomizedDelaySec = "45min";
      allowReboot = false;
    };

    stateVersion = "25.11";
  };
}
