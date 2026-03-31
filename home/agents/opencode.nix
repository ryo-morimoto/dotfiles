{
  pencilMcp,
  compound-engineering-plugin,
  ...
}:

let
  ceSkillsPath = "${compound-engineering-plugin}/plugins/compound-engineering/skills";

  # Map compound-engineering skills to OpenCode commands
  # SKILL.md content is used directly as command content
  ceCommand = name: "${ceSkillsPath}/${name}/SKILL.md";
in
{
  programs.opencode = {
    enable = true;
    # Uses pkgs.opencode from nixpkgs (default)

    settings = {
      "$schema" = "https://opencode.ai/config.json";
      mcp = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
          enabled = true;
        };
        pencil = {
          command = [
            (toString pencilMcp)
            "--app"
            "desktop"
          ];
          enabled = true;
          type = "local";
        };
        vibe_kanban = {
          command = [
            "npx"
            "-y"
            "vibe-kanban@latest"
            "--mcp"
          ];
          enabled = true;
          type = "local";
        };
      };
    };

    rules = builtins.readFile ../../config/opencode/AGENTS.md;

    # compound-engineering commands (sourced from flake input)
    commands = {
      "ce:brainstorm" = ceCommand "ce-brainstorm";
      "ce:compound" = ceCommand "ce-compound";
      "ce:plan" = ceCommand "ce-plan";
      "ce:review" = ceCommand "ce-review";
      "ce:work" = ceCommand "ce-work";
      "deepen-plan" = ceCommand "ce-ideate";
      "feature-video" = ceCommand "feature-video";
      "resolve_todo_parallel" = ceCommand "resolve-pr-feedback";
      "test-browser" = ceCommand "test-browser";
    };
  };
}
