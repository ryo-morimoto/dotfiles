{
  context7-skills,
  evolutionary-naming,
  mattpocock-skills,
  mizchi-skills,
  mgechev-skills,
  ...
}:
{
  programs.agent-skills = {
    enable = true;

    sources = {
      personal = {
        path = ../../skills;
      };
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
      enable = [
        "fp-typescript"
        "repo-doctor"
        "evolutionary-naming"
        "context7-mcp"
        "context7-cli"
        "find-docs"
        "grill-me"
        "improve-codebase-architecture"
        "to-prd"
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
