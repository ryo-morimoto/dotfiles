{
  config,
  claude-plugins-official ? null,
  kuu-marketplace ? null,
  callstack-agent-skills ? null,
  expo-plugins ? null,
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
    "https://mcp.linear.app/*"
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
  mcpServers = {
    exa = {
      transport = "stdio";
      command = "npx";
      args = [
        "-y"
        "exa-mcp-server"
      ];
      clients = [
        "claude"
        "codex"
      ];
    };
    secretary = {
      transport = "http";
      url = "https://secretary.ryo-morimoto-dev.workers.dev/mcp";
      clients = [
        "claude"
        "codex"
      ];
    };
    context7 = {
      transport = "http";
      url = "https://mcp.context7.com/mcp";
      clients = [
        "claude"
        "codex"
      ];
    };
    linear-work = {
      transport = "http";
      url = "https://mcp.linear.app/mcp";
      clients = [
        "claude"
        "codex"
      ];
    };
    linear-personal = {
      transport = "http";
      url = "https://mcp.linear.app/mcp";
      clients = [
        "claude"
        "codex"
      ];
    };
  };
  sharedClaudeCode = {
    enabledPlugins = {
      "commit-commands@claude-plugins-official" = true;
      "feature-dev@claude-plugins-official" = true;
      "pr-review-toolkit@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "lua-lsp@claude-plugins-official" = true;
      "code-simplifier@claude-plugins-official" = true;
      "deslop@kuu-marketplace" = true;
      "dig@kuu-marketplace" = true;
      "fix-ci@kuu-marketplace" = true;
      "decomposition@kuu-marketplace" = true;
      "claude-md-management@claude-plugins-official" = true;
      "skill-creator@claude-plugins-official" = true;
      "coderabbit@claude-plugins-official" = true;
      "data@claude-plugins-official" = true;
      "clangd-lsp@claude-plugins-official" = true;
      "know@know" = true;
      "react-native-best-practices@callstack-agent-skills" = true;
      "github@callstack-agent-skills" = true;
      "github-actions@callstack-agent-skills" = true;
      "upgrading-react-native@callstack-agent-skills" = true;
      "react-native-brownfield-migration@callstack-agent-skills" = true;
      "expo@expo-plugins" = true;
      "superpowers@claude-plugins-official" = false;
      "frontend-design@claude-plugins-official" = false;
      "code-review@claude-plugins-official" = false;
      "security-guidance@claude-plugins-official" = false;
      "semgrep@claude-plugins-official" = false;
      "ralph-loop@claude-plugins-official" = false;
      "agent-sdk-dev@claude-plugins-official" = false;
      "gopls-lsp@claude-plugins-official" = false;
      "rust-analyzer-lsp@claude-plugins-official" = false;
      "plugin-dev@claude-plugins-official" = false;
      "autofix-bot@claude-plugins-official" = false;
    };
    plugins = [ ];
    marketplaces = {
      inherit
        claude-plugins-official
        kuu-marketplace
        callstack-agent-skills
        expo-plugins
        ;
      know = ../../config/knowledge/know;
    };
  };
  sharedClaudeHookSources = {
    linear-response-strip = {
      source = ./hooks/linear-response-strip.sh;
      matcher = "mcp__linear-(personal|work)__(save_issue|save_project)";
      event = "PostToolUse";
    };
    sandbox-broker-pretool = {
      commandFn = pkgs: "${pkgs.sandbox-broker}/libexec/sandbox-broker/claude-code-hook.sh";
      matcher = "(Read|Edit|Write|Bash)";
      event = "PreToolUse";
    };
  };
in
{
  imports = [
    ./claude-code.nix
    ./codex.nix
    ./skills.nix
  ];

  _module.args = {
    inherit
      dangerousBashPatterns
      mcpServers
      secretPathRules
      sharedClaudeCode
      sharedClaudeHookSources
      sharedAgentPolicy
      trustedHttpDomains
      trustedReadPaths
      trustedWritePaths
      ;
  };
}
