{ pkgs, ... }:

{
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
}
