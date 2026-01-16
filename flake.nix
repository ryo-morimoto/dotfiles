{
	description = "My dotfiles";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		claude-code = {
			url = "github:ryoppippi/claude-code-overlay";
		};
	};

	outputs = { nixpkgs, home-manager, claude-code, ... }:
		let
			system = "x86_64-linux";
			pkgs = import nixpkgs {
				inherit system;
				config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
					"claude-code"
				];
				overlays = [ claude-code.overlays.default ];
			};
		in
		{
			homeConfigurations."ryo-morimoto" = home-manager.lib.homeManagerConfiguration {
				inherit pkgs;
				modules = [ ./home.nix ];
			};
		};
}
