{
  config,
  lib,
  pencilMcp,
  pkgs,
  ...
}:
let
  ghqDir = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto";
  codexConfigDir = "${config.home.homeDirectory}/.codex";
  codexConfigFile = "${codexConfigDir}/config.toml";
  codexSettings = {
    personality = "pragmatic";
    model = "gpt-5.3-codex";
    model_reasoning_effort = "xhigh";
    features.multi_agent = true;
    projects = {
      "${ghqDir}/dotfiles".trust_level = "trusted";
      "${ghqDir}/newsfeed-ai".trust_level = "trusted";
      "${ghqDir}/ccinsights".trust_level = "trusted";
    };
    mcp_servers.pencil = {
      command = toString pencilMcp;
      args = [
        "--app"
        "desktop"
      ];
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
  };

  home.activation.installMutableCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "${codexConfigDir}"

    if [ -L "${codexConfigFile}" ]; then
      ${pkgs.coreutils}/bin/rm -f "${codexConfigFile}"
    fi

    ${pkgs.coreutils}/bin/install -m 600 "${codexConfigSource}" "${codexConfigFile}"
  '';
}
