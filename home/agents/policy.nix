{ config, ... }:

let
  homeDir = config.home.homeDirectory;
  ghqDir = "${homeDir}/ghq";
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
  safeBashPatterns = [
    "git status*"
    "git diff*"
    "git log*"
    "nixfmt *"
    "nix flake check*"
  ];
  riskyBashPatterns = [
    "git push *"
    "rm *"
    "curl *"
    "wget *"
    "git reset *"
    "git checkout -- *"
  ];
  agentPolicyData = {
    defaultAction = "ask";

    bash = {
      allow = safeBashPatterns;
      deny = riskyBashPatterns;
    };

    pathAccess = {
      trustedRead = trustedReadPaths;
      trustedWrite = trustedWritePaths;
      externalDirectoryAllow = map (path: "${path}/**") trustedReadPaths;
      secretRules = [
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
      claudeAdditionalReadAllow = [
        "Read(~/.claude/skills/**)"
        "Read(~/.claude/plugins/cache/**)"
      ];
    };

    http = {
      trustedDomains = trustedHttpDomains;
    };

    runtime = {
      approvalPolicy = "on-request";
      sandboxMode = "workspace-write";
      sandboxNetworkAccess = false;
      logUserPrompt = false;
      allowedApprovalPolicies = [
        "untrusted"
        "on-request"
      ];
      allowedSandboxModes = [
        "read-only"
        "workspace-write"
      ];
      allowedWebSearchModes = [ "cached" ];
      prefixRules = [
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
    };

    opencode = {
      share = "disabled";
      tools = {
        read = "allow";
        glob = "allow";
        grep = "allow";
        list = "allow";
        edit = "ask";
        task = "ask";
        skill = "ask";
        webfetch = "ask";
      };
    };

    claude = {
      autoUpdatesChannel = "stable";
      minimumVersion = "2.1.12";
      outputStyle = "default";
    };
  };
in
{
  inherit trustedReadPaths trustedWritePaths trustedHttpDomains;
  dangerousBashPatterns = map (pattern: "Bash(${pattern})") riskyBashPatterns;
  inherit agentPolicyData;

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

}
