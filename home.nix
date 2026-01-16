{ pkgs, ... }:

{
	home.username = "ryo-o";
	home.homeDirectory = "/home/ryo-o";
	home.stateVersion = "25.11";

	programs.home-manager.enable = true;

	programs.git = {
		enable = true;
		settings.user = {
			name = "ryo-morimoto";
			email = "ryo.morimoto.dev@gmail.com";
		};
	};
}
