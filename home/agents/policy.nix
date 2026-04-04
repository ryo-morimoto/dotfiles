{ config, ... }:

let
  homeDir = config.home.homeDirectory;
  ghqDir = "${homeDir}/ghq";
in
{
  dangerousBashPatterns = [
    "Bash(git push *)"
    "Bash(rm *)"
    "Bash(curl *)"
    "Bash(wget *)"
    "Bash(git reset *)"
    "Bash(git checkout -- *)"
  ];

  secretPathRules = [
    "Read(~/.ssh/**)"
    "Read(~/.gnupg/**)"
    "Read(./.env)"
    "Read(./.env.*)"
    "Read(./secrets/**)"
    "Edit(~/.ssh/**)"
    "Edit(~/.gnupg/**)"
    "Edit(./.env)"
    "Edit(./.env.*)"
    "Edit(./secrets/**)"
  ];

  trustedReadPaths = [
    ghqDir
    "${homeDir}/obsidian"
  ];

  trustedWritePaths = [
    ghqDir
  ];

  trustedHttpDomains = [
    "https://mcp.context7.com/*"
    "https://secretary.ryo-morimoto-dev.workers.dev/*"
  ];

  claudeManagedMcp = {
    mcpServers = {
      exa = {
        type = "stdio";
        command = "npx";
        args = [
          "-y"
          "exa-mcp-server"
        ];
      };
      secretary = {
        type = "http";
        url = "https://secretary.ryo-morimoto-dev.workers.dev/mcp";
      };
      vibe_kanban = {
        type = "stdio";
        command = "npx";
        args = [
          "-y"
          "vibe-kanban@latest"
          "--mcp"
        ];
      };
    };
  };

  codexRequirements = {
    allowed_approval_policies = [
      "untrusted"
      "on-request"
    ];
    allowed_sandbox_modes = [
      "read-only"
      "workspace-write"
    ];
    allowed_web_search_modes = [ "cached" ];
    rules.prefix_rules = [
      {
        pattern = [
          { token = "rm"; }
        ];
        decision = "forbidden";
        justification = "Avoid destructive file deletion from Codex.";
      }
      {
        pattern = [
          { token = "git"; }
          { token = "push"; }
        ];
        decision = "prompt";
        justification = "Require explicit approval before publishing changes.";
      }
      {
        pattern = [
          {
            any_of = [
              "curl"
              "wget"
            ];
          }
        ];
        decision = "prompt";
        justification = "Require approval before pulling external content.";
      }
    ];
    mcp_servers = {
      exa.identity.command = "npx";
      secretary.identity.url = "https://secretary.ryo-morimoto-dev.workers.dev/mcp";
      vibe_kanban.identity.command = "npx";
    };
  };

  codexManagedConfig = {
    approval_policy = "on-request";
    sandbox_mode = "workspace-write";
    sandbox_workspace_write.network_access = false;
    otel.log_user_prompt = false;
  };
}
