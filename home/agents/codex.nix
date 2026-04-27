{
  config,
  lib,
  compoundEngineering,
  mcpServers,
  ...
}:
let
  ghqDir = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto";
  renderCompoundEngineeringPrompt =
    prompt:
    ''
      ---
      description: ${builtins.toJSON prompt.description}
    ''
    + lib.optionalString (prompt.argumentHint != null) ''
      argument-hint: ${builtins.toJSON prompt.argumentHint}
    ''
    + ''
      ---

      Use the ${prompt.skill} skill for this workflow and follow its instructions exactly.

      Treat any text after the prompt name as the workflow context to pass through.
    '';
  mkCodexMcp =
    server:
    if server.transport == "stdio" then
      {
        inherit (server) command args;
      }
    else
      {
        inherit (server) url;
      };
in
{
  programs.codex = {
    context = builtins.readFile ./_AGENTS.md;
    enable = true;
    settings = {
      personality = "pragmatic";
      model = "gpt-5.5";
      review_model = "gpt-5.5";
      model_reasoning_effort = "high";
      sandbox_mode = "workspace-write";
      approvals_reviewer = "guardian_subagent";
      approval_policy.granular = {
        sandbox_approval = true;
        rules = true;
        skill_approval = false;
        request_permissions = false;
        mcp_elicitations = true;
      };
      features.multi_agent = true;
      otel.log_user_prompt = false;
      sandbox_workspace_write = {
        network_access = true;
        exclude_slash_tmp = false;
        exclude_tmpdir_env_var = false;
        writable_roots = [ ghqDir ];
      };
      rules.prefix_rules = [
        {
          pattern = [ { token = "rm"; } ];
          decision = "forbidden";
          justification = "Destructive file deletion is not allowed";
        }
        {
          pattern = [
            { token = "git"; }
            { token = "push"; }
          ];
          decision = "prompt";
          justification = "Require approval before publishing changes";
        }
      ];
      mcp_servers = lib.mapAttrs (_: mkCodexMcp) (
        lib.filterAttrs (_: server: builtins.elem "codex" server.clients) mcpServers
      );
    };
    inherit (compoundEngineering.codex) skills;
  };

  home.file = lib.mapAttrs' (
    name: prompt:
    lib.nameValuePair ".codex/prompts/${name}.md" {
      text = renderCompoundEngineeringPrompt prompt;
    }
  ) compoundEngineering.codex.prompts;
}
