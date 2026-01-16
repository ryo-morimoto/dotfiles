{ pkgs, ... }:

{
	imports = [
		./modules/git.nix
		./modules/shell/zsh.nix
	];

	home.username = "ryo-o";
	home.homeDirectory = "/home/ryo-o";
	home.stateVersion = "25.11";

	programs.home-manager.enable = true;
}
