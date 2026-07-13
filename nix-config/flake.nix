{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
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
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    seiren = {
      url = "github:ryo-morimoto/seiren/nix-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    soulforge = {
      url = "github:ryo-morimoto/soulforge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-hazkey = {
      url = "github:aster-void/nix-hazkey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-claude-code = {
      url = "github:ryoppippi/nix-claude-code";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      dms,
      niri-flake,
      zen-browser,
      banto,
      agenix,
      voxtype,
      fenix,
      moonbit-overlay,
      seiren,
      soulforge,
      nix-hazkey,
      nix-claude-code,
      codex-cli-nix,
      ...
    }:
    let
      communityOverlay = final: prev: {
        codex = prev.codex.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            substituteInPlace "$out/bin/codex" \
              --replace-fail "exec \"$out/bin/codex-raw\"  \"\$@\"" \
                             "exec -a codex \"$out/bin/codex-raw\" \"\$@\""
          '';
        });
        catppuccin-gtk =
          (prev.catppuccin-gtk.override {
            python3 = prev.python3.override {
              packageOverrides = _pythonFinal: pythonPrev: {
                catppuccin = pythonPrev.catppuccin.overridePythonAttrs (_old: {
                  doCheck = false;
                  pythonImportsCheck = [ ];
                });
              };
            };
          }).overrideAttrs
            (old: {
              postPatch = (old.postPatch or "") + ''
                substituteInPlace sources/build/args.py \
                  --replace-fail "        type=bool," ""
              '';
            });
        zen-browser = zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
        seiren-mcp = seiren.packages.${final.stdenv.hostPlatform.system}.default;
        soulforge = soulforge.packages.${final.stdenv.hostPlatform.system}.default;
      };
    in
    {
      nixosConfigurations.ryobox = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit agenix;
        };
        modules = [
          ./hosts/ryobox
          agenix.nixosModules.default
          banto.nixosModules.default
          nix-hazkey.nixosModules.hazkey
          {
            services.hazkey.server.package = nix-hazkey.packages.x86_64-linux.hazkey-server.override {
              enableVulkan = true;
            };
          }
          home-manager.nixosModules.home-manager
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            nixpkgs.overlays = [
              fenix.overlays.default
              moonbit-overlay.overlays.default
              nix-claude-code.overlays.default
              codex-cli-nix.overlays.default
              communityOverlay
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
                  zen-browser.homeModules.beta
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
    };
}
