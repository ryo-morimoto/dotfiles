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
	];

	home.file = {
		".gitconfig".source = ./git/.gitconfig;
		".config/gh/config.yml".source = ./gh/config.yml;
		".zshrc".source = ./zsh/.zshrc;
		".config/nvim".source = ./nvim;
		".claude/settings.json".source = ./claude/settings.json;
	};
}
