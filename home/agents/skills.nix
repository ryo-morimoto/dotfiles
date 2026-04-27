{
  context7-skills,
  evolutionary-naming,
  mattpocock-skills,
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
      ];
    };

    targets = {
      claude.enable = true;
      codex.enable = true;
      agents.enable = true;
    };
  };
}
