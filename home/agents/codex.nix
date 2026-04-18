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
      model = "gpt-5.4";
      review_model = "gpt-5.4";
      model_reasoning_effort = "high";
      approval_policy = "never";
      sandbox_mode = "workspace-write";
      features.multi_agent = true;
      otel.log_user_prompt = false;
      sandbox_workspace_write = {
        network_access = true;
        # Keep /tmp and $TMPDIR writable — many CLIs (git, npm, build tools)
        # stage intermediate files there and silently break when excluded.
        exclude_slash_tmp = false;
        exclude_tmpdir_env_var = false;
        # Grant writes across the whole personal ghq tree so cross-repo edits
        # (e.g. invoking tools that live in a sibling checkout) don't trip
        # the workspace-write fence.
        writable_roots = [ ghqDir ];
      };
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
