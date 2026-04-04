{
  config,
  lib,
  mcpServers,
  sharedClaudeCode,
  sharedAgentPolicy,
  ...
}:

let
  mkClaudeMcp =
    server:
    if server.transport == "stdio" then
      {
        type = "stdio";
        inherit (server) command args;
      }
    else
      {
        type = "http";
        inherit (server) url;
      };
  claudeUserSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    sandbox = {
      enabled = false;
    };
    statusLine = {
      type = "command";
      command = "node /home/ryo-morimoto/.claude/hud/omc-hud.mjs";
    };
    inherit (sharedAgentPolicy.claude) autoUpdatesChannel minimumVersion outputStyle;
    inherit (sharedClaudeCode) enabledPlugins;
  };
in
{
  programs.claude-code = {
    enable = true;

    settings = claudeUserSettings;

    memory.text = builtins.readFile ./_AGENTS.md;

    inherit (sharedClaudeCode)
      marketplaces
      plugins
      ;

    mcpServers = lib.mapAttrs (_: mkClaudeMcp) (
      lib.filterAttrs (_: server: builtins.elem "claude" server.clients) mcpServers
    );

    # Skills managed by agent-skills-nix (see skills.nix)
  };

  home.file = {
    ".claude/settings.json".text = builtins.toJSON claudeUserSettings;

    # keel plugin: mutable symlink for live development
    ".claude/plugins/keel".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/keel";
  }
  // lib.mapAttrs' (
    name: source:
    lib.nameValuePair ".claude/plugins/marketplaces/${name}" {
      inherit source;
    }
  ) sharedClaudeCode.marketplaces;
}
