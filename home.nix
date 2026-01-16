{ pkgs, ... }:

{
	home.username = "ryo-o";
	home.homeDirectory = "/home/ryo-o";
	home.stateVersion = "25.11";

	programs.home-manager.enable = true;

	home.packages = with pkgs; [
		git
		gh
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

	home.file = {
		".config/git/config".source = ./git/.gitconfig;
		".config/gh/config.yml".source = ./gh/config.yml;
		".config/zsh/.zshrc".source = ./zsh/.zshrc;
		".zshenv".text = ''
			export ZDOTDIR="$HOME/.config/zsh"
		'';
		".config/nvim".source = ./nvim;
		".config/claude/settings.json".source = ./claude/settings.json;
		".config/claude/statusline.sh" = {
			source = ./claude/statusline.sh;
			executable = true;
		};
	};
}
