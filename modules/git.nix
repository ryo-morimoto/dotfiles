{ pkgs, ... }:

{
	programs.git = {
		enable = true;
		settings.user = {
			name = "ryo-morimoto";
			email = "ryo.morimoto.dev@gmail.com";
		};
	};

	programs.gh = {
		enable = true;
		settings = {
			git_protocol = "ssh";
		};
	};
}
