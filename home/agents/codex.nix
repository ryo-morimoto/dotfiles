{
  lib,
  mcpServers,
  ...
}:
let
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
      sandbox_mode = "danger-full-access";
      approval_policy = "never";
      features = {
        multi_agent = true;
        codex_hooks = true;
      };
      otel.log_user_prompt = false;
      mcp_servers = lib.mapAttrs (_: mkCodexMcp) (
        lib.filterAttrs (_: server: builtins.elem "codex" server.clients) mcpServers
      );
    };
  };
}
