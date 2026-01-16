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
	];

	programs.claude-code = {
		enable = true;
		package = pkgs.claude-code;
	};

	programs.git = {
		enable = true;
		userName = "ryo-morimoto";
		userEmail = "ryo.morimoto.dev@gmail.com";
		extraConfig = {
			init.defaultBranch = "main";
			core.pager = "bat --plain";
		};
	};

	programs.gh = {
		enable = true;
		settings = {
			git_protocol = "https";
		};
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
	};
}
