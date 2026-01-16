{ pkgs, ... }:

{
	home.username = "ryo-o";
	home.homeDirectory = "/home/ryo-o";
	home.stateVersion = "25.11";

	programs.home-manager.enable = true;

	programs.git = {
		enable = true;
		settings = {
			core.pager = "bat --plain";

			user = {
				name = "ryo-morimoto";
				email = "ryo.morimoto.dev@gmail.com";
			};
		};
	};

	programs.gh = {
		enable = true;
		settings = {
			git_protocol = "ssh";
		};
	};

	programs.bat = {
		enable = true;
	};

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
			c = "claude";
			cy = "claude --dangerously-skip-permissions";
		};
	};

	programs.neovim = {
		enable = true;
		defaultEditor = true;
		vimAlias = true;
		viAlias = true;
	};

	home.file.".claude/settings.json".source = ./claude/settings.json;
}
