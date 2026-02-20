{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
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
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    voxtype = {
      url = "github:peteonrails/voxtype";
    };
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      llm-agents,
      dms,
      niri-flake,
      tmuxcc-src,
      banto,
      agenix,
      voxtype,
      moonbit-overlay,
      ...
    }:
    let
      localOverlay = final: _prev: {
        vibe-kanban = final.callPackage ./packages/vibe-kanban.nix { };
        claude-squad = final.callPackage ./packages/claude-squad.nix { };
        tmuxcc = final.callPackage ./packages/tmuxcc.nix { inherit tmuxcc-src; };
        entire = final.callPackage ./packages/entire.nix { };
      };
    in
    {
      nixosConfigurations.ryobox = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/ryobox
          agenix.nixosModules.default
          banto.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            nixpkgs.overlays = [
              moonbit-overlay.overlays.default
              localOverlay
              llm-agents.overlays.default
            ];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.ryo-morimoto = {
                imports = [
                  niri-flake.homeModules.config
                  dms.homeModules.dank-material-shell
                  dms.homeModules.niri
                  voxtype.homeManagerModules.default
                  ./home
                ];
              };
              extraSpecialArgs = {
                inherit dms voxtype;
              };
            };
          }
        ];
      };
    };
}
