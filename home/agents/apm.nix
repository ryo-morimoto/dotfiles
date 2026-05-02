{
  lib,
  inputs ? { },
  ...
}:

let
  apm = import ../../packages/apm.nix { inherit lib; };
  apmDsl = apm.dsl;

  apmLock = apmDsl.mkInputLock {
    inherit inputs;
    packages = {
      astronomer-agents = "astronomer/agents";
      callstack-agent-skills = "callstackincubator/agent-skills";
      claude-plugins-official = "anthropics/claude-plugins-official";
      coderabbit-claude-plugin = "coderabbitai/claude-plugin";
      compound-engineering = {
        input = "compound-engineering-plugin";
        source = "EveryInc/compound-engineering-plugin";
        path = "plugins/compound-engineering";
      };
      expo-plugins = "expo/skills";
      kuu-marketplace = {
        input = "kuu-marketplace";
        source = "fumiya-kume/claude-code";
      };
      mattpocock-skills = "mattpocock/skills";
      superpowers = "obra/superpowers";
    };
  };

  compoundEngineering = import ./compound-engineering.nix {
    inherit
      apmDsl
      apmLock
      ;
  };
  lock = apmLock;
  mkLeaves =
    names:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = { };
      }) names
    );
  mkDependency =
    package: path:
    apmDsl.mkPinnedDependency {
      inherit
        lock
        package
        path
        ;
    };
  mkPackage =
    package:
    apmDsl.mkPinnedDependency {
      inherit lock package;
    };

  claudeOfficialPlugins = [
    "commit-commands"
    "feature-dev"
    "pr-review-toolkit"
    "typescript-lsp"
    "pyright-lsp"
    "lua-lsp"
    "code-simplifier"
    "claude-md-management"
    "skill-creator"
    "clangd-lsp"
  ];

  kuuPlugins = [
    "deslop"
    "dig"
    "fix-ci"
    "decomposition"
  ];

  claudePluginDependencies =
    (map (name: mkDependency "claude-plugins-official" "plugins/${name}") claudeOfficialPlugins)
    ++ (map (name: mkDependency "kuu-marketplace" name) kuuPlugins)
    ++ [
      (mkPackage "coderabbit-claude-plugin")
      (mkPackage "astronomer-agents")
      (mkPackage "callstack-agent-skills")
      (mkDependency "expo-plugins" "plugins/expo")
      (toString ../../config/knowledge/know)
    ];

  mattpocockProductivitySkills = [
    "caveman"
    "grill-me"
    "write-a-skill"
  ];

  mattpocockEngineeringSkills = [
    "diagnose"
    "grill-with-docs"
    "improve-codebase-architecture"
    "setup-matt-pocock-skills"
    "tdd"
    "zoom-out"
  ];

  mattpocockSkillDependencies =
    (apmDsl.mkPrimitiveDependencies {
      lock = apmLock;
      package = "mattpocock-skills";
      selectedSkills = mattpocockProductivitySkills;
      skills = mkLeaves mattpocockProductivitySkills;
      skillPath = name: "skills/productivity/${name}";
    })
    ++ (apmDsl.mkPrimitiveDependencies {
      lock = apmLock;
      package = "mattpocock-skills";
      selectedSkills = mattpocockEngineeringSkills;
      skills = mkLeaves mattpocockEngineeringSkills;
      skillPath = name: "skills/engineering/${name}";
    });

  apmTargets = [
    "claude"
    "codex"
  ];

  sharedApm = {
    enable = true;
    targets = apmTargets;
    manifest = {
      name = "ryo-agent-packages";
      version = "1.0.0";
      target = apmTargets;
      dependencies.apm =
        compoundEngineering.dependencies
        ++ mattpocockSkillDependencies
        ++ claudePluginDependencies
        ++ [
          (mkPackage "superpowers")
        ];
    };
  };
in
{
  imports = [
    apm.homeManagerModule
  ];

  _module.args = {
    inherit sharedApm;
  };

  programs.agent-skills = {
    enable = true;

    sources = {
      personal = {
        path = ../../skills;
      };
      context7 = {
        input = "context7-skills";
        subdir = "skills";
      };
      evolutionary-naming = {
        input = "evolutionary-naming";
        subdir = "skills";
      };
      mizchi = {
        input = "mizchi-skills";
      };
      skill-creator = {
        input = "mgechev-skills";
        subdir = "skill";
      };
    };

    skills = {
      enable = [
        "fp-typescript"
        "repo-doctor"
        "evolutionary-naming"
        "context7-mcp"
        "context7-cli"
        "find-docs"
        "empirical-prompt-tuning"
        "skill-creator"
      ];
    };

    targets = {
      claude.enable = true;
      codex.enable = true;
      agents.enable = true;
    };
  };
}
