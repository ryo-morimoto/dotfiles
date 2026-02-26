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
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
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
    starlintLinuxBin = {
      url = "https://github.com/mizchi/starlint/releases/latest/download/starlint-linux-x64.tar.gz";
      flake = false;
    };
    starlintDarwinArm64Bin = {
      url = "https://github.com/mizchi/starlint/releases/latest/download/starlint-macos-arm64.tar.gz";
      flake = false;
    };
    # FIXME: pinned for khal; remove when nixpkgs#khal sphinx build is fixed
    nixpkgs-khal.url = "github:nixos/nixpkgs/0182a361324364ae3f436a63005877674cf45efb";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-khal,
      home-manager,
      llm-agents,
      dms,
      niri-flake,
      zen-browser,
      tmuxcc-src,
      banto,
      agenix,
      voxtype,
      moonbit-overlay,
      starlintLinuxBin,
      starlintDarwinArm64Bin,
      ...
    }:
    let
      localOverlay = final: _prev: {
        vibe-kanban = final.callPackage ./packages/vibe-kanban.nix { };
        claude-squad = final.callPackage ./packages/claude-squad.nix { };
        tmuxcc = final.callPackage ./packages/tmuxcc.nix { inherit tmuxcc-src; };
        beacon = final.callPackage ./packages/beacon.nix { };
        entire = final.callPackage ./packages/entire.nix { };
        zen-browser = zen-browser.packages.${final.system}.default;
        starlint = final.callPackage ./packages/starlint.nix {
          inherit starlintLinuxBin starlintDarwinArm64Bin;
        };
        # FIXME: remove when nixpkgs#khal sphinx build is fixed upstream
        inherit (nixpkgs-khal.legacyPackages.${final.system}) khal;
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
