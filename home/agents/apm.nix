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
      claude-plugins-official = "anthropics/claude-plugins-official";
      coderabbit-claude-plugin = "coderabbitai/claude-plugin";
      compound-engineering = {
        input = "compound-engineering-plugin";
        source = "EveryInc/compound-engineering-plugin";
        path = "plugins/compound-engineering";
      };
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

  claudeOfficialPlugins = [
    "commit-commands"
    "feature-dev"
    "pr-review-toolkit"
    "code-simplifier"
    "claude-md-management"
  ];

  kuuPlugins = [
    "deslop"
    "dig"
    "fix-ci"
    "decomposition"
  ];

  claudePluginDependencies =
    (map (name: mkDependency "claude-plugins-official" "plugins/${name}") claudeOfficialPlugins)
    ++ (map (name: mkDependency "kuu-marketplace" name) kuuPlugins);

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

  superpowersSkills = [
    "brainstorming"
    "dispatching-parallel-agents"
    "executing-plans"
    "finishing-a-development-branch"
    "receiving-code-review"
    "requesting-code-review"
    "subagent-driven-development"
    "systematic-debugging"
    "test-driven-development"
    "using-git-worktrees"
    "using-superpowers"
    "verification-before-completion"
    "writing-plans"
    "writing-skills"
  ];

  superpowersSkillDependencies = apmDsl.mkPrimitiveDependencies {
    lock = apmLock;
    package = "superpowers";
    selectedSkills = superpowersSkills;
    skills = mkLeaves superpowersSkills;
    skillPath = name: "skills/${name}";
  };

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
        ++ superpowersSkillDependencies
        ++ claudePluginDependencies;
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
