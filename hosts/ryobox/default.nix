{ config, pkgs, ... }:

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

    # banto task dashboard
    banto.enable = true;

    # Caddy reverse proxy (TLS via Let's Encrypt DNS-01 + Cloudflare)
    caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
        hash = "sha256-dnhEjopeA0UiI+XVYHYpsjcEI6Y1Hacbi28hVKYQURg="; # caddy 2.10.2 + cloudflare v0.2.2
      };
      virtualHosts."banto.ryobox.xyz" = {
        extraConfig = ''
          reverse_proxy localhost:3000
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }
        '';
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
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Caddy: load Cloudflare API token (decrypted by agenix)
  age.secrets.caddy-cloudflare = {
    file = ../../secrets/caddy-cloudflare.age;
    owner = "caddy";
    group = "caddy";
    mode = "0400";
  };
  systemd.services.caddy.serviceConfig.EnvironmentFile = config.age.secrets.caddy-cloudflare.path;

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
    ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };

  # /bin/bash symlink (for scripts with #!/bin/bash shebang)
  system.activationScripts.binbash = ''
    ln -sfn ${pkgs.bash}/bin/bash /bin/bash
  '';

  # Nix
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
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

  # Automatic system upgrade (GitOps: pulls from GitHub)
  system.autoUpgrade = {
    enable = true;
    flake = "github:ryo-morimoto/dotfiles#ryobox";
    dates = "05:00";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };

  system.stateVersion = "25.11";
}
