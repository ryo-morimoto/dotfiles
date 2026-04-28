{
  context7-skills,
  evolutionary-naming,
  mattpocock-skills,
  mizchi-skills,
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
      mattpocock = {
        path = mattpocock-skills;
      };
      mizchi = {
        path = mizchi-skills;
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
        "design-an-interface"
        "grill-me"
        "improve-codebase-architecture"
        "domain-model"
        "to-prd"
        "empirical-prompt-tuning"
      ];
    };

    targets = {
      claude.enable = true;
      codex.enable = true;
      agents.enable = true;
    };
  };
}
