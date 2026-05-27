{
  config,
  lib,
  inputs ? { },
  ...
}:

let
  apm = import ../../packages/apm.nix { inherit lib; };
  apmDsl = apm.dsl;
  localSkillsRoot = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles/skills";

  apmLock = apmDsl.mkInputLock {
    inherit inputs;
    packages = {
      compound-engineering = {
        input = "compound-engineering-plugin";
        source = "EveryInc/compound-engineering-plugin";
        path = "plugins/compound-engineering";
      };
      context7-skills = "upstash/context7";
      evolutionary-naming = "kawasima/evolutionary-naming";
      mattpocock-skills = "mattpocock/skills";
      mgechev-skills = "mgechev/skills-best-practices";
      mizchi-skills = "mizchi/skills";
      superpowers = "obra/superpowers";
    };
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
  mkPackageDependency =
    package:
    apmDsl.mkPackageDependency {
      inherit
        lock
        package
        ;
    };

  compoundEngineeringDependency = mkPackageDependency "compound-engineering";
  superpowersDependency = mkPackageDependency "superpowers";

  personalSkillDependencies = [
    "${localSkillsRoot}/fp-typescript"
    "${localSkillsRoot}/repo-doctor"
  ];

  context7Skills = [
    "context7-cli"
    "context7-mcp"
    "find-docs"
  ];

  context7SkillDependencies = apmDsl.mkPrimitiveDependencies {
    lock = apmLock;
    package = "context7-skills";
    selectedSkills = context7Skills;
    skills = mkLeaves context7Skills;
    skillPath = name: "skills/${name}";
  };

  evolutionaryNamingSkillDependencies = apmDsl.mkPrimitiveDependencies {
    lock = apmLock;
    package = "evolutionary-naming";
    selectedSkills = [ "evolutionary-naming" ];
    skills = mkLeaves [ "evolutionary-naming" ];
    skillPath = name: "skills/${name}";
  };

  mizchiSkillDependencies = apmDsl.mkPrimitiveDependencies {
    lock = apmLock;
    package = "mizchi-skills";
    selectedSkills = [ "empirical-prompt-tuning" ];
    skills = mkLeaves [ "empirical-prompt-tuning" ];
    skillPath = name: name;
  };

  mgechevSkillDependencies = apmDsl.mkPrimitiveDependencies {
    lock = apmLock;
    package = "mgechev-skills";
    selectedSkills = [ "skill-creator" ];
    skills = mkLeaves [ "skill-creator" ];
    skillPath = _name: "skill";
  };

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
      dependencies.apm = [
        compoundEngineeringDependency
        superpowersDependency
      ]
      ++ personalSkillDependencies
      ++ context7SkillDependencies
      ++ evolutionaryNamingSkillDependencies
      ++ mizchiSkillDependencies
      ++ mgechevSkillDependencies
      ++ mattpocockSkillDependencies;
      dependencies.mcp = [
        {
          name = "context7";
          registry = false;
          transport = "http";
          url = "https://mcp.context7.com/mcp";
        }
        {
          name = "exa";
          registry = false;
          transport = "stdio";
          command = "npx";
          args = [
            "-y"
            "exa-mcp-server"
          ];
        }
        {
          name = "secretary";
          registry = false;
          transport = "http";
          url = "https://secretary.ryo-morimoto-dev.workers.dev/mcp";
        }
        {
          name = "figma";
          registry = false;
          transport = "http";
          url = "https://mcp.figma.com/mcp";
        }
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
}
