{
  config,
  lib,
  compoundEngineering,
  mcpServers,
  pkgs,
  ...
}:
let
  ghqDir = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto";
  codexConfigDir = "${config.home.homeDirectory}/.codex";
  codexConfigFile = "${codexConfigDir}/config.toml";
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
  codexSettings = {
    personality = "pragmatic";
    model = "gpt-5.3-codex";
    model_reasoning_effort = "xhigh";
    approval_policy = "never";
    sandbox_mode = "workspace-write";
    features.multi_agent = true;
    otel.log_user_prompt = false;
    sandbox_workspace_write.network_access = true;
    projects = {
      "${ghqDir}/dotfiles".trust_level = "trusted";
      "${ghqDir}/newsfeed-ai".trust_level = "trusted";
      "${ghqDir}/ccinsights".trust_level = "trusted";
    };
    mcp_servers = lib.mapAttrs (_: mkCodexMcp) (
      lib.filterAttrs (_: server: builtins.elem "codex" server.clients) mcpServers
    );
  };
  codexConfigSource = (pkgs.formats.toml { }).generate "codex-config" codexSettings;
in
{
  programs.codex = {
    context = builtins.readFile ./_AGENTS.md;
    enable = true;
    settings = { };
    inherit (compoundEngineering.codex) skills;
  };

  home.file = lib.mapAttrs' (
    name: prompt:
    lib.nameValuePair ".codex/prompts/${name}.md" {
      text = renderCompoundEngineeringPrompt prompt;
    }
  ) compoundEngineering.codex.prompts;

  home.activation.installMutableCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "${codexConfigDir}"

    if [ -L "${codexConfigFile}" ]; then
      ${pkgs.coreutils}/bin/rm -f "${codexConfigFile}"
    fi

    ${pkgs.coreutils}/bin/install -m 600 "${codexConfigSource}" "${codexConfigFile}"
  '';
}
