{
  config,
  ...
}:

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
  dangerousBashPatterns = map (pattern: "Bash(${pattern})") riskyBashPatterns;
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
  sharedAgentPolicy = {
    defaultAction = "ask";
    bash = {
      allow = safeBashPatterns;
      deny = riskyBashPatterns;
    };
    pathAccess = {
      trustedRead = trustedReadPaths;
      trustedWrite = trustedWritePaths;
      externalDirectoryAllow = map (path: "${path}/**") trustedReadPaths;
      secretRules = secretPathRules;
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
    claude = {
      autoUpdatesChannel = "stable";
      minimumVersion = "2.1.12";
      outputStyle = "default";
    };
  };
  mcpServers = { };
  sharedClaudeHookSources = { };
in
{
  imports = [
    ./claude-code.nix
    ./codex.nix
    ./apm.nix
  ];

  _module.args = {
    inherit
      dangerousBashPatterns
      mcpServers
      secretPathRules
      sharedClaudeHookSources
      sharedAgentPolicy
      trustedHttpDomains
      trustedReadPaths
      trustedWritePaths
      ;
  };
}
