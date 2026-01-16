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
		bun2nix = {
			url = "github:nix-community/bun2nix";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { nixpkgs, home-manager, claude-code, bun2nix, ... }:
		let
			system = "x86_64-linux";
			pkgs = import nixpkgs {
				inherit system;
				config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
					"claude"
				];
				overlays = [
					claude-code.overlays.default
					bun2nix.overlays.default
				];
			};
		in
		{
			homeConfigurations."ryo-morimoto" = home-manager.lib.homeManagerConfiguration {
				inherit pkgs;
				modules = [ ./home.nix ];
			};

			devShells.${system}.default = pkgs.mkShell {
				packages = [
					pkgs.bun
					pkgs.bun2nix
				];
			};
		};
}
