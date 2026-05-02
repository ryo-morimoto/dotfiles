{
  lib,
  pkgs,
  mcpServers,
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
    hooks = claudeHooksByEvent;
  };
in
{
  programs.claude-code = {
    enable = true;

    settings = claudeUserSettings;

    context = builtins.readFile ./_AGENTS.md;

    mcpServers = lib.mapAttrs (_: mkClaudeMcp) (
      lib.filterAttrs (_: server: builtins.elem "claude" server.clients) mcpServers
    );

    # Agent packages are installed declaratively by APM (see apm.nix).
  };
}
