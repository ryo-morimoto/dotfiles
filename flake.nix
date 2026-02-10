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
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake = {
      url = "github:sodiboo/niri-flake";
    };
    tmuxcc-src = {
      url = "github:nyanko3141592/tmuxcc";
      flake = false;
    };
    banto = {
      url = "github:ryo-morimoto/banto";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      claude-code-overlay,
      codex-cli-nix,
      dms,
      niri-flake,
      tmuxcc-src,
      banto,
      ...
    }:
    let
      localOverlay = final: prev: {
        vibe-kanban = final.callPackage ./packages/vibe-kanban.nix { };
        claude-squad = final.callPackage ./packages/claude-squad.nix { };
        tmuxcc = final.callPackage ./packages/tmuxcc.nix { inherit tmuxcc-src; };
      };
    in
    {
      nixosConfigurations.ryobox = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/ryobox
          banto.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            nixpkgs.overlays = [
              localOverlay
              claude-code-overlay.overlays.default
              codex-cli-nix.overlays.default
            ];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.ryo-morimoto = {
                imports = [
                  niri-flake.homeModules.config
                  dms.homeModules.dank-material-shell
                  dms.homeModules.niri
                  ./home
                ];
              };
              extraSpecialArgs = {
                inherit dms;
              };
            };
          }
        ];
      };
    };
}
