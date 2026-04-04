{
  config,
  lib,
  compoundEngineering,
  policy,
  ...
}:

let
  ceSkillsPath = compoundEngineering.skillsPath;
  agentPolicy = policy.agentPolicyData;
  mkPermissionRule =
    rules:
    {
      "*" = agentPolicy.defaultAction;
    }
    // builtins.listToAttrs (
      map (pattern: {
        name = pattern;
        value = "allow";
      }) (rules.allow or [ ])
    )
    // builtins.listToAttrs (
      map (pattern: {
        name = pattern;
        value = "deny";
      }) (rules.deny or [ ])
    );
  mkOpenCodeMcp =
    server:
    if server.transport == "stdio" then
      {
        type = "local";
        command = [ server.command ] ++ server.args;
        enabled = true;
      }
    else
      {
        type = "remote";
        url = server.url;
        enabled = true;
      };
  opencodePermission = {
    "*" = agentPolicy.defaultAction;
  }
  // agentPolicy.opencode.tools
  // {
    bash = mkPermissionRule agentPolicy.bash;
    external_directory = mkPermissionRule {
      allow = agentPolicy.pathAccess.externalDirectoryAllow;
    };
  };
  opencodeMcp = lib.mapAttrs (_: mkOpenCodeMcp) (
    lib.filterAttrs (_: server: builtins.elem "opencode" server.clients) agentPolicy.mcpServers
  );

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
      share = agentPolicy.opencode.share;
      permission = opencodePermission;
      mcp = opencodeMcp;
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
