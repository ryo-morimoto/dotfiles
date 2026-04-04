{
  config,
  lib,
  compoundEngineering,
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
  codexSettings = {
    personality = "pragmatic";
    model = "gpt-5.3-codex";
    model_reasoning_effort = "xhigh";
    features.multi_agent = true;
    approval_policy = "on-request";
    sandbox_mode = "workspace-write";
    sandbox_workspace_write.network_access = false;
    projects = {
      "${ghqDir}/dotfiles".trust_level = "trusted";
      "${ghqDir}/newsfeed-ai".trust_level = "trusted";
      "${ghqDir}/ccinsights".trust_level = "trusted";
    };
    mcp_servers = {
      exa = {
        command = "npx";
        args = [
          "-y"
          "exa-mcp-server"
        ];
      };
      secretary.url = "https://secretary.ryo-morimoto-dev.workers.dev/mcp";
      vibe_kanban = {
        command = "npx";
        args = [
          "-y"
          "vibe-kanban@latest"
          "--mcp"
        ];
      };
    };
  };
  codexConfigSource = (pkgs.formats.toml { }).generate "codex-config" codexSettings;
in
{
  programs.codex = {
    custom-instructions = builtins.readFile ./_AGENTS.md;
    enable = true;
    # Uses pkgs.codex from nixpkgs (default)
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
