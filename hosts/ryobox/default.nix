{ pkgs, ... }:

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
  };

  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Desktop (Niri)
  environment.systemPackages = with pkgs; [
    # Bar & Launcher
    waybar
    fuzzel

    # Notifications & OSD
    mako
    swayosd

    # Wallpaper
    swww

    # Lock & Power
    swaylock
    wlogout

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
    pam.services.swaylock = { };
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
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
