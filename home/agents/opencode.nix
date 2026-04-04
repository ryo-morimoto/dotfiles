{
  config,
  compoundEngineering,
  ...
}:

let
  ceSkillsPath = compoundEngineering.skillsPath;
  homeDir = config.home.homeDirectory;

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
      share = "disabled";
      permission = {
        "*" = "ask";
        read = "allow";
        glob = "allow";
        grep = "allow";
        list = "allow";
        edit = "ask";
        task = "ask";
        skill = "ask";
        webfetch = "ask";
        external_directory = {
          allowed = [
            "${homeDir}/ghq"
            "${homeDir}/obsidian"
          ];
          mode = "ask";
        };
        bash = {
          default = "ask";
          allow = [
            "git status*"
            "git diff*"
            "git log*"
            "nixfmt *"
            "nix flake check*"
          ];
          deny = [
            "git push *"
            "rm *"
            "curl *"
            "wget *"
            "git reset *"
            "git checkout -- *"
          ];
        };
      };
      mcp = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
          enabled = true;
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
        secretary = {
          type = "remote";
          url = "https://secretary.ryo-morimoto-dev.workers.dev/mcp";
          enabled = true;
        };
      };
    };

    rules = builtins.readFile ./_AGENTS.md;

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
