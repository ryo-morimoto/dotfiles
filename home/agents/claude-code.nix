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
  # Resolve hook command: commandFn (deferred pkg ref), command (literal), or source (wrapped .sh).
  resolveHookCommand =
    name: spec:
    if spec ? commandFn then
      spec.commandFn pkgs
    else
      spec.command or "${
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [ pkgs.jq ];
          text = builtins.readFile spec.source;
        }
      }/bin/${name}";
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
              command = resolveHookCommand entry.name entry;
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
    model = "opus[1m]";
    effortLevel = "high";
    sandbox = {
      enabled = false;
    };
    permissions.defaultMode = "bypassPermissions";
    inherit (sharedAgentPolicy.claude) autoUpdatesChannel minimumVersion outputStyle;
    inherit (sharedClaudeCode) enabledPlugins;
    hooks = claudeHooksByEvent;
  };
  claudeUserSettingsFile = pkgs.writeText "claude-code-settings.json" (
    builtins.toJSON claudeUserSettings
  );
  sanitizeMarketplace =
    name: source:
    pkgs.runCommandLocal "claude-marketplace-${name}"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        mkdir -p "$out"
        cp -R --no-preserve=mode,ownership ${source}/. "$out"/

        marketplace="$out/.claude-plugin/marketplace.json"
        if [ -f "$marketplace" ]; then
          missing_sources="$(
            jq -r '.plugins[]? | select(.source | type == "string") | .source | select(startswith("./"))' "$marketplace" \
              | while IFS= read -r plugin_source; do
                  plugin_path="$out/''${plugin_source#./}"
                  if [ ! -d "$plugin_path" ]; then
                    printf '%s\n' "$plugin_source"
                  fi
                done
          )"

          if [ -n "$missing_sources" ]; then
            missing_json="$(printf '%s\n' "$missing_sources" | jq -R . | jq -s .)"
            jq --argjson missing "$missing_json" \
              '.plugins |= map(. as $plugin | select(($plugin.source | type != "string") or (($missing | index($plugin.source)) | not)))' \
              "$marketplace" > "$marketplace.tmp"
            mv "$marketplace.tmp" "$marketplace"
          fi
        fi
      '';
  marketplaces = lib.mapAttrs sanitizeMarketplace sharedClaudeCode.marketplaces;
  # Nix 管理分の known_marketplaces.json コンテンツ
  knownMarketplacesContent = builtins.toJSON (
    lib.mapAttrs (_name: source: {
      source = {
        source = "directory";
        path = toString source;
      };
      installLocation = toString source;
      lastUpdated = "1970-01-01T00:00:00Z";
    }) marketplaces
  );
  knownMarketplacesFile = pkgs.writeText "claude-code-known-marketplaces.json" knownMarketplacesContent;
in
{
  programs.claude-code = {
    enable = true;

    context = builtins.readFile ./_AGENTS.md;

    # marketplaces は渡さない — known_marketplaces.json を mutable にするため activation で管理
    inherit (sharedClaudeCode) plugins;

    mcpServers = lib.mapAttrs (_: mkClaudeMcp) (
      lib.filterAttrs (_: server: builtins.elem "claude" server.clients) mcpServers
    );

    # Skills managed by agent-skills-nix (see skills.nix)
  };

  home = {
    activation = {
      # settings.json を mutable copy としてマージ配置
      # APM が hooks を追記するため、Home Manager の symlink 管理にはしない
      claudeCodeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        target="$HOME/.claude/settings.json"
        if [ -L "$target" ]; then
          rm "$target"
        fi

        if [ -f "$target" ]; then
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target" ${claudeUserSettingsFile} > "$target.tmp"
          mv "$target.tmp" "$target"
        else
          install -Dm644 ${claudeUserSettingsFile} "$target"
        fi
      '';

      # known_marketplaces.json を mutable copy としてマージ配置
      # Nix 管理分を最新に更新しつつ、Claude Code が追加した非管理分を保持
      claudeKnownMarketplaces = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target="$HOME/.claude/plugins/known_marketplaces.json"
        if [ -f "$target" ]; then
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target" ${knownMarketplacesFile} > "$target.tmp"
          mv "$target.tmp" "$target"
        else
          install -Dm644 ${knownMarketplacesFile} "$target"
        fi
      '';
    };

    file = lib.mapAttrs' (
      name: source:
      lib.nameValuePair ".claude/plugins/marketplaces/${name}" {
        inherit source;
      }
    ) marketplaces;
  };
}
