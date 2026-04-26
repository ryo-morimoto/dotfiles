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
    starlintLinuxBin = {
      url = "https://github.com/mizchi/starlint/releases/latest/download/starlint-linux-x64.tar.gz";
      flake = false;
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
    agent-skills-nix = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nix-claude-code = {
      # pinned to 2.1.119 — 2.1.120 has session bug, rollback to url once upstream publishes fix
      url = "github:ryoppippi/nix-claude-code/59bb590492ee6af9eeb0d8e9e8f6a73140aec761";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    compound-engineering-plugin = {
      url = "github:EveryInc/compound-engineering-plugin";
      flake = false;
    };
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    codex-plugin-cc = {
      url = "github:openai/codex-plugin-cc";
      flake = false;
    };
    kuu-marketplace = {
      url = "github:fumiya-kume/claude-code";
      flake = false;
    };
    moonbit-practice-marketplace = {
      url = "github:mizchi/moonbit-practice";
      flake = false;
    };
    keel-marketplace = {
      url = "github:ryo-morimoto/keel";
      flake = false;
    };
    callstack-agent-skills = {
      url = "github:callstackincubator/agent-skills";
      flake = false;
    };
    expo-plugins = {
      url = "github:expo/skills";
      flake = false;
    };
    pm-skills = {
      url = "github:phuryn/pm-skills";
      flake = false;
    };
    evolutionary-naming = {
      url = "github:kawasima/evolutionary-naming";
      flake = false;
    };
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    context-mode-marketplace = {
      url = "github:mksglu/context-mode";
      flake = false;
    };
  };

  outputs =
    {
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
      agent-skills-nix,
      nix-claude-code,
      compound-engineering-plugin,
      claude-plugins-official,
      codex-plugin-cc,
      kuu-marketplace,
      moonbit-practice-marketplace,
      keel-marketplace,
      callstack-agent-skills,
      expo-plugins,
      pm-skills,
      evolutionary-naming,
      mattpocock-skills,
      context-mode-marketplace,
      starlintLinuxBin,
      ...
    }:
    let
      localOverlay = final: _prev: {
        cursor-agent = final.callPackage ./packages/cursor-agent.nix { };
        zen-browser = zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
        seiren-mcp = seiren.packages.${final.stdenv.hostPlatform.system}.default;
        showboat = final.callPackage ./packages/showboat.nix { };
        rodney = final.callPackage ./packages/rodney.nix { };
        agent-browser = final.callPackage ./packages/agent-browser.nix { };
        grepika = final.callPackage ./packages/grepika.nix { };
        portless = final.callPackage ./packages/portless.nix { };
        k1low-mo = final.callPackage ./packages/mo.nix { };
        codedb = final.callPackage ./packages/codedb.nix { };
        soulforge = soulforge.packages.${final.stdenv.hostPlatform.system}.default;
        starlint = final.callPackage ./packages/starlint.nix {
          inherit starlintLinuxBin;
        };
        coderabbit = final.callPackage ./packages/coderabbit.nix { };
      };
    in
    {
      nixosConfigurations.ryobox = nixpkgs.lib.nixosSystem {
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
              localOverlay
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
                  agent-skills-nix.homeManagerModules.default
                  zen-browser.homeModules.beta
                  ./home
                ];
              };
              extraSpecialArgs = {
                inherit
                  dms
                  voxtype
                  compound-engineering-plugin
                  claude-plugins-official
                  codex-plugin-cc
                  kuu-marketplace
                  moonbit-practice-marketplace
                  keel-marketplace
                  callstack-agent-skills
                  expo-plugins
                  pm-skills
                  evolutionary-naming
                  mattpocock-skills
                  context-mode-marketplace
                  ;
              };
            };
          }
        ];
      };
    };
}
