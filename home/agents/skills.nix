{ compound-engineering-plugin, ... }:
{
  programs.agent-skills = {
    enable = true;

    sources = {
      personal = {
        path = ../../skills;
      };
      compound-engineering = {
        path = "${compound-engineering-plugin}/plugins/compound-engineering/skills";
        idPrefix = "ce";
      };
    };

    skills.enableAll = true;

    targets = {
      claude.enable = true;
      codex.enable = true;
      agents.enable = true;
    };
  };
}
