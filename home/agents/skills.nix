{
  context7-skills,
  evolutionary-naming,
  mattpocock-skills,
  mizchi-skills,
  mgechev-skills,
  ...
}:
let
  personalSkills = [
    "fp-typescript"
    "repo-doctor"
  ];

  externalSkills = {
    mattpocock = {
      enable = [
        "diagnose"
        "grill-with-docs"
        "improve-codebase-architecture"
        "setup-matt-pocock-skills"
        "tdd"
        "zoom-out"
      ];
      enableAll = [
        "mattpocock-productivity"
      ];
    };
    kawasima = {
      enable = [
        "evolutionary-naming"
      ];
      enableAll = [ ];
    };
    upstash = {
      enable = [
        "context7-mcp"
        "context7-cli"
        "find-docs"
      ];
      enableAll = [ ];
    };
    mizchi = {
      enable = [
        "ast-grep-practice"
        "empirical-prompt-tuning"
        "retrospective-codify"
      ];
      enableAll = [ ];
    };
    mgechev = {
      enable = [
        "skill-creator"
      ];
      enableAll = [ ];
    };
  };
in
{
  programs.agent-skills = {
    enable = true;

    sources = {
      # Local skills maintained in this repository.
      personal = {
        path = ../../skills;
      };

      # External skills pinned as flake inputs.
      context7 = {
        path = context7-skills;
        subdir = "skills";
      };
      evolutionary-naming = {
        path = evolutionary-naming;
        subdir = "skills";
      };
      mattpocock-engineering = {
        path = mattpocock-skills;
        subdir = "skills/engineering";
      };
      mattpocock-productivity = {
        path = mattpocock-skills;
        subdir = "skills/productivity";
      };
      mizchi = {
        path = mizchi-skills;
      };
      skill-creator = {
        path = mgechev-skills;
        subdir = "skill";
      };
    };

    skills = {
      # External source buckets that should track upstream additions.
      enableAll =
        externalSkills.mattpocock.enableAll
        ++ externalSkills.kawasima.enableAll
        ++ externalSkills.upstash.enableAll
        ++ externalSkills.mizchi.enableAll
        ++ externalSkills.mgechev.enableAll;

      enable =
        personalSkills
        ++ externalSkills.mattpocock.enable
        ++ externalSkills.kawasima.enable
        ++ externalSkills.upstash.enable
        ++ externalSkills.mizchi.enable
        ++ externalSkills.mgechev.enable;
    };

    targets = {
      claude.enable = true;
      codex.enable = true;
      agents.enable = true;
    };
  };
}
