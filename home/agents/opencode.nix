{
  lib,
  compoundEngineering,
  mcpServers,
  ...
}:

let
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
        inherit (server) url;
        enabled = true;
      };
  opencodeMcp = lib.mapAttrs (_: mkOpenCodeMcp) (
    lib.filterAttrs (_: server: builtins.elem "opencode" server.clients) mcpServers
  );
in
{
  programs.opencode = {
    enable = true;
    # Uses pkgs.opencode from nixpkgs (default)

    settings = {
      "$schema" = "https://opencode.ai/config.json";
      share = "disabled";
      permission = "allow";
      mcp = opencodeMcp;
    };

    rules = builtins.readFile ./_AGENTS.md;

    inherit (compoundEngineering.opencode) commands;
  };
}
