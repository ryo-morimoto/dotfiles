{
  lib,
  pkgs,
  mcpServers,
  sharedClaudeCode,
  sharedClaudeHookSources,
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
  # Materialize each hook script body via writeShellApplication so jq is
  # guaranteed on PATH regardless of the runtime shell environment.
  mkHookScript =
    name: spec:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.jq ];
      text = builtins.readFile spec.source;
    };
  claudeHookScripts = lib.mapAttrs mkHookScript sharedClaudeHookSources;
  # Group hooks by event (PostToolUse, PreToolUse, ...) into the shape
  # settings.hooks expects: { <event>: [ { matcher; hooks = [ {type;command} ]; } ]; }
  claudeHooksByEvent =
    lib.mapAttrs
      (
        _event: entries:
        map (entry: {
          inherit (entry) matcher;
          hooks = [
            {
              type = "command";
              command = "${claudeHookScripts.${entry.name}}/bin/${entry.name}";
            }
          ];
        }) entries
      )
      (
        builtins.groupBy (entry: entry.event) (
          lib.mapAttrsToList (name: spec: spec // { inherit name; }) sharedClaudeHookSources
        )
      );
  claudeUserSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    model = "claude-opus-4-6";
    effortLevel = "medium";
    sandbox = {
      enabled = false;
    };
    inherit (sharedAgentPolicy.claude) autoUpdatesChannel minimumVersion outputStyle;
    inherit (sharedClaudeCode) enabledPlugins;
    hooks = claudeHooksByEvent;
  };
  # Nix 管理分の known_marketplaces.json コンテンツ
  knownMarketplacesContent = builtins.toJSON (
    lib.mapAttrs (_name: source: {
      source = {
        source = "directory";
        path = toString source;
      };
      installLocation = toString source;
      lastUpdated = "1970-01-01T00:00:00Z";
    }) sharedClaudeCode.marketplaces
  );
  knownMarketplacesFile = pkgs.writeText "claude-code-known-marketplaces.json" knownMarketplacesContent;
in
{
  programs.claude-code = {
    enable = true;

    settings = claudeUserSettings;

    context = builtins.readFile ./_AGENTS.md;

    # marketplaces は渡さない — known_marketplaces.json を mutable にするため activation で管理
    inherit (sharedClaudeCode) plugins;

    mcpServers = lib.mapAttrs (_: mkClaudeMcp) (
      lib.filterAttrs (_: server: builtins.elem "claude" server.clients) mcpServers
    );

    # Skills managed by agent-skills-nix (see skills.nix)
  };

  # known_marketplaces.json を mutable copy としてマージ配置
  # Nix 管理分を最新に更新しつつ、Claude Code が追加した非管理分を保持
  home.activation.claudeKnownMarketplaces = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.claude/plugins/known_marketplaces.json"
    if [ -f "$target" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target" ${knownMarketplacesFile} > "$target.tmp"
      mv "$target.tmp" "$target"
    else
      install -Dm644 ${knownMarketplacesFile} "$target"
    fi
  '';

  home.file = lib.mapAttrs' (
    name: source:
    lib.nameValuePair ".claude/plugins/marketplaces/${name}" {
      inherit source;
    }
  ) sharedClaudeCode.marketplaces;
}
