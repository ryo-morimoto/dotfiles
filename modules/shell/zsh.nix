{ pkgs, ... }:

{
	programs.zsh = {
		enable = true;

		history = {
			size = 10000;
			save = 10000;
			ignoreDups = true;
		};

		shellAliases = {
			ll = "ls -la";
			g = "git";
			hms = "home-manager switch --flake .#ryo-morimoto";
		};
	};
}
