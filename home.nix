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

		# Hyprland & Wayland
		hyprland
		xdg-desktop-portal-hyprland

		# UI
		waybar
		ghostty

		# Launcher & Notifications
		rofi-wayland
		dunst

		# Utilities
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
		papirus-icon-theme
		adwaita-icon-theme
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

		".config/hypr/hyprland.conf".source = ./hyprland/hyprland.conf;
		".config/hypr/keybinds.conf".source = ./hyprland/keybinds.conf;
		".config/hypr/windowrules.conf".source = ./hyprland/windowrules.conf;
		".config/hypr/autostart.conf".source = ./hyprland/autostart.conf;

		".config/waybar/config.jsonc".source = ./waybar/config.jsonc;
		".config/waybar/style.css".source = ./waybar/style.css;

		".config/ghostty/config".source = ./ghostty/config;
		".config/rofi/config.rasi".source = ./rofi/config.rasi;
		".config/dunst/dunstrc".source = ./dunst/dunstrc;
		".config/btop/btop.conf".source = ./btop/btop.conf;
		".config/fastfetch/config.jsonc".source = ./fastfetch/config.jsonc;

		".config/wallust/wallust.toml".source = ./wallust/wallust.toml;
		".config/wallust/templates".source = ./wallust/templates;
		".config/wallust/defaults".source = ./wallust/defaults;
		".config/waypaper/config.ini".source = ./waypaper/config.ini;
	};
}
