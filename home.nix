{ pkgs, ... }:

{
	home.username = "ryo-o";
	home.homeDirectory = "/home/ryo-o";
	home.stateVersion = "25.11";

	programs.home-manager.enable = true;

	programs.git = {
		enable = true;
		settings = {
			init.defaultBranch = "main";
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
			git_protocol = "https";
		};
	};

	programs.bat = {
		enable = true;
	};

	programs.zsh.enable = true;

	programs.neovim = {
		enable = true;
		defaultEditor = true;
		vimAlias = true;
		viAlias = true;
	};

	home.file = {
		".zshrc".source = ./zsh/.zshrc;
		".config/nvim".source = ./nvim;
		".claude/settings.json".source = ./claude/settings.json;
	};
}
