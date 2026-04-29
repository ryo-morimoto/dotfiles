{
  config,
  lib,
  pkgs,
  mcpServers,
  ...
}:
let
  ghqDir = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto";
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
      sandbox_mode = "workspace-write";
      approvals_reviewer = "guardian_subagent";
      approval_policy.granular = {
        sandbox_approval = true;
        rules = true;
        skill_approval = false;
        request_permissions = false;
        mcp_elicitations = true;
      };
      features = {
        multi_agent = true;
        codex_hooks = true;
      };
      otel.log_user_prompt = false;
      sandbox_workspace_write = {
        network_access = true;
        exclude_slash_tmp = false;
        exclude_tmpdir_env_var = false;
        writable_roots = [ ghqDir ];
      };
      rules.prefix_rules = [
        {
          pattern = [ { token = "rm"; } ];
          decision = "forbidden";
          justification = "Destructive file deletion is not allowed";
        }
        {
          pattern = [
            { token = "git"; }
            { token = "push"; }
          ];
          decision = "prompt";
          justification = "Require approval before publishing changes";
        }
      ];
      hooks = {
        PreToolUse = [
          {
            matcher = "^(Bash|read_file|apply_patch|list_dir)$";
            hooks = [
              {
                type = "command";
                command = "${pkgs.sandbox-broker}/libexec/sandbox-broker/codex-hook.sh";
                timeout = 10;
              }
            ];
          }
        ];
      };
      mcp_servers = lib.mapAttrs (_: mkCodexMcp) (
        lib.filterAttrs (_: server: builtins.elem "codex" server.clients) mcpServers
      );
    };
  };
}
