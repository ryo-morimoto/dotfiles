{ config, pkgs, ... }:

{
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

  programs = {
    # DankMaterialShell desktop shell
    dank-material-shell = {
      enable = true;
      enableDynamicTheming = true;
      enableClipboardPaste = true;
      enableSystemMonitoring = true;
      systemd.enable = true;
      niri = {
        enableKeybinds = true;
        enableSpawn = false;
        includes.enable = false;
      };
    };

    voxtype = {
      enable = true;
      package = pkgs.voxtype;
      engine = "whisper";
      model.name = "large-v3-turbo";
      service.enable = true;
      settings = {
        hotkey = {
          enabled = true;
          key = "RIGHTALT";
          mode = "push_to_talk";
        };
        whisper = {
          language = "ja";
          translate = false;
        };
        output = {
          mode = "type";
          fallback_to_clipboard = true;
        };
      };
    };

    # Niri compositor (managed by niri-flake, DMS merges keybinds/spawn into settings)
    niri.package = pkgs.niri;
    niri.settings = {
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
        { command = [ "awww-daemon" ]; }
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

    zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;
      profiles.default = {
        isDefault = true;
        path = "7e6w7csf.Default Profile";
        settings = {
          "zen.tab-unloader.timeout-minutes" = 10;
          "browser.tabs.min_inactive_duration_before_unload" = 300000;
          "browser.cache.memory.capacity" = 262144;
        };
      };
    };
  };

  xdg = {
    desktopEntries = {
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

      "orca-desktop" = {
        name = "Orca";
        genericName = "Agentic IDE";
        # orca-serve が ~/.config/orca(既定 userData)を占有しているため、
        # desktop client は別 profile で起動しないと single-instance で即終了する。
        exec = "appimage-run ${config.home.homeDirectory}/Applications/orca-linux.AppImage --user-data-dir=${config.home.homeDirectory}/.config/orca-desktop";
        terminal = false;
        categories = [ "Development" ];
        settings.StartupWMClass = "orca";
      };

      "zed" = {
        name = "Zed";
        genericName = "Text Editor";
        comment = "A high-performance, multiplayer code editor.";
        exec = "${config.home.homeDirectory}/.local/share/mise/shims/zed %U";
        terminal = false;
        startupNotify = true;
        settings.TryExec = "${config.home.homeDirectory}/.local/share/mise/shims/zed";
        icon = "${config.home.homeDirectory}/.local/share/mise/installs/github-zed-industries-zed/latest/zed.app/share/icons/hicolor/512x512/apps/zed.png";
        categories = [
          "Utility"
          "TextEditor"
          "Development"
          "IDE"
        ];
        mimeType = [
          "text/plain"
          "application/x-zerosize"
          "x-scheme-handler/zed"
        ];
        actions = {
          "NewWorkspace" = {
            name = "Open a new workspace";
            exec = "${config.home.homeDirectory}/.local/share/mise/shims/zed --new %U";
          };
        };
      };
    };

    mimeApps.enable = true;

    configFile."mimeapps.list".force = true;
  };
}
