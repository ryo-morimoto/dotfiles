{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-overlay = {
      url = "github:ryoppippi/claude-code-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ralph-tui-overlay = {
      url = "github:ryo-morimoto/ralph-tui-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      claude-code-overlay,
      codex-cli-nix,
      ralph-tui-overlay,
      ...
    }:
    {
      nixosConfigurations.ryobox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/ryobox
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              claude-code-overlay.overlays.default
              codex-cli-nix.overlays.default
              ralph-tui-overlay.overlays.default
            ];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.ryo-morimoto = import ./home;
            };
          }
        ];
      };
    };
}
