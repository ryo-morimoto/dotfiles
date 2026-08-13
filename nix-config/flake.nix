{
  description = "NixOS configuration";

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
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
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake = {
      url = "github:sodiboo/niri-flake";
    };
    nix-claude-code = {
      url = "github:ryoppippi/nix-claude-code";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-hazkey = {
      url = "github:aster-void/nix-hazkey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    seiren = {
      url = "github:ryo-morimoto/seiren/nix-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    soulforge = {
      url = "github:ryo-morimoto/soulforge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
  };

  outputs =
    inputs@{
      agenix,
      codex-cli-nix,
      dms,
      fenix,
      home-manager,
      moonbit-overlay,
      niri-flake,
      nix-claude-code,
      nix-hazkey,
      nixpkgs,
      voxtype,
      ...
    }:
    let
      overlays = import ./overlays { inherit inputs; };
    in
    {
      nixosConfigurations.ryobox = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit agenix;
        };
        modules = [
          ./hosts/ryobox
          agenix.nixosModules.default
          nix-hazkey.nixosModules.hazkey
          {
            services.hazkey.server.package = nix-hazkey.packages.x86_64-linux.hazkey-server.override {
              enableVulkan = true;
            };
          }
          home-manager.nixosModules.home-manager
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            # overlays.community は codex を上書きするため codex-cli-nix より後に置く
            nixpkgs.overlays = [
              fenix.overlays.default
              moonbit-overlay.overlays.default
              nix-claude-code.overlays.default
              codex-cli-nix.overlays.default
              overlays.local
              overlays.community
            ];
            home-manager = {
              backupFileExtension = "hm-bak";
              useGlobalPkgs = true;
              useUserPackages = true;
              users.ryo-morimoto = {
                imports = [
                  niri-flake.homeModules.config
                  dms.homeModules.dank-material-shell
                  dms.homeModules.niri
                  voxtype.homeManagerModules.default
                  inputs.zen-browser.homeModules.beta
                  ./home
                ];
              };
              extraSpecialArgs = {
                inherit voxtype;
                inherit inputs;
              };
            };
          }
        ];
      };

      packages.x86_64-linux.portless =
        (import nixpkgs {
          system = "x86_64-linux";
          overlays = [ overlays.local ];
        }).portless;
    };
}
