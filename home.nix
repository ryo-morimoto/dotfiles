{ pkgs, ... }:

{
	home.username = "ryo-o";
	home.homeDirectory = "/home/ryo-o";
	home.stateVersion = "25.11";

	programs.home-manager.enable = true;

	home.packages = with pkgs; [
		bat
		zsh
		neovim
		jq
		bc

		# Hyprland & Wayland (Phase 1)
		hyprland
		xdg-desktop-portal-hyprland

		# UI (Phase 2)
		waybar
		ghostty

		# Launcher & Notifications (Phase 3)
		rofi-wayland
		dunst

		# Utilities (Phase 4)
		swww
		hyprlock
		hyprshot
		grim
		slurp
		wl-clipboard
		cliphist
		swappy
		btop
		fastfetch
		wallust
		waypaper
	];

	programs.git = {
		enable = true;
		settings = {
			user.name = "ryo-morimoto";
			user.email = "ryo.morimoto.dev@gmail.com";
			init.defaultBranch = "main";
			core.pager = "bat --plain";
			credential."https://github.com".helper = "!gh auth git-credential";
		};
	};

	programs.gh = {
		enable = true;
		gitCredentialHelper.enable = false;
		settings = {
			git_protocol = "https";
		};
	};

	programs.claude-code = {
		enable = true;
		package = pkgs.claude-code;
	};

	home.file = {
		".config/zsh/.zshrc".source = ./zsh/.zshrc;
		".zshenv".text = ''
			export ZDOTDIR="''${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
			export CLAUDE_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/claude"
		'';
		".config/nvim".source = ./nvim;
		".config/claude/settings.json".source = ./claude/settings.json;
		".config/claude/statusline.sh" = {
			source = ./claude/statusline.sh;
			executable = true;
		};

		# Hyprland
		".config/hypr/hyprland.conf".source = ./hyprland/hyprland.conf;
		".config/hypr/keybinds.conf".source = ./hyprland/keybinds.conf;
		".config/hypr/windowrules.conf".source = ./hyprland/windowrules.conf;
		".config/hypr/autostart.conf".source = ./hyprland/autostart.conf;

		# Waybar
		".config/waybar/config.jsonc".source = ./waybar/config.jsonc;
		".config/waybar/style.css".source = ./waybar/style.css;

		# Ghostty
		".config/ghostty/config".source = ./ghostty/config;

		# Rofi
		".config/rofi/config.rasi".source = ./rofi/config.rasi;

		# Dunst
		".config/dunst/dunstrc".source = ./dunst/dunstrc;

		# Btop
		".config/btop/btop.conf".source = ./btop/btop.conf;

		# Fastfetch
		".config/fastfetch/config.jsonc".source = ./fastfetch/config.jsonc;

		# Wallust
		".config/wallust/wallust.toml".source = ./wallust/wallust.toml;
		".config/wallust/templates".source = ./wallust/templates;

		# Waypaper
		".config/waypaper/config.ini".source = ./waypaper/config.ini;
	};
}
