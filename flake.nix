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
		nixgl = {
			url = "github:nix-community/nixGL";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { nixpkgs, home-manager, claude-code, nixgl, ... }:
		let
			system = "x86_64-linux";
			pkgs = import nixpkgs {
				inherit system;
				config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
					"claude"
				];
				overlays = [ claude-code.overlays.default ];
			};
		in
		{
			homeConfigurations."ryo-morimoto" = home-manager.lib.homeManagerConfiguration {
				inherit pkgs;
				extraSpecialArgs = {
					inherit nixgl;
				};
				modules = [ ./home.nix ];
			};
		};
}
