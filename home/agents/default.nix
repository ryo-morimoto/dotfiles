{
  config,
  lib ? null,
  compound-engineering-plugin ? null,
  claude-plugins-official ? null,
  keel-marketplace ? null,
  kuu-marketplace ? null,
  moonbit-practice-marketplace ? null,
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
        "opencode"
      ];
    };
    context7 = {
      transport = "http";
      url = "https://mcp.context7.com/mcp";
      clients = [ "opencode" ];
    };
  };
  ceSkillsPath = "${compound-engineering-plugin}/plugins/compound-engineering/skills";
  ceSkills = [
    {
      name = "ce:brainstorm";
      source = "ce-brainstorm";
      prompt = {
        name = "ce-brainstorm";
        description = "Explore requirements and approaches before planning";
        argumentHint = "[feature idea or problem to explore]";
      };
      opencodeCommand = "ce:brainstorm";
    }
    {
      name = "ce:compound";
      source = "ce-compound";
      prompt = {
        name = "ce-compound";
        description = "Document a recently solved problem to compound your team's knowledge";
        argumentHint = null;
      };
      opencodeCommand = "ce:compound";
    }
    {
      name = "ce:ideate";
      source = "ce-ideate";
      prompt = {
        name = "ce-ideate";
        description = "Discover high-impact project improvements through divergent ideation and adversarial filtering";
        argumentHint = "[feature, focus area, or constraint]";
      };
      opencodeCommand = "deepen-plan";
    }
    {
      name = "ce:plan";
      source = "ce-plan";
      prompt = {
        name = "ce-plan";
        description = "Turn feature ideas into detailed implementation plans";
        argumentHint = "[optional: feature description, requirements doc path, plan path to deepen, or improvement idea]";
      };
      opencodeCommand = "ce:plan";
    }
    {
      name = "ce:review";
      source = "ce-review";
      prompt = {
        name = "ce-review";
        description = "Multi-agent code review before merging";
        argumentHint = "[blank to review current branch, or provide PR link]";
      };
      opencodeCommand = "ce:review";
    }
    {
      name = "ce:work";
      source = "ce-work";
      prompt = {
        name = "ce-work";
        description = "Execute plans with worktrees and task tracking";
        argumentHint = "[Plan doc path or description of work. Blank to auto use latest plan doc]";
      };
      opencodeCommand = "ce:work";
    }
    {
      name = "feature-video";
      source = "feature-video";
      opencodeCommand = "feature-video";
    }
    {
      name = "resolve-pr-feedback";
      source = "resolve-pr-feedback";
      opencodeCommand = "resolve_todo_parallel";
    }
    {
      name = "test-browser";
      source = "test-browser";
      opencodeCommand = "test-browser";
    }
  ];
  compoundEngineering = {
    plugin = compound-engineering-plugin;
    skillsPath = ceSkillsPath;
    claude = {
      marketplaceName = "every-marketplace";
      marketplaceSource = compound-engineering-plugin;
      enabledPlugins = {
        "compound-engineering@every-marketplace" = true;
        "coding-tutor@every-marketplace" = true;
      };
    };
    codex = {
      skills = builtins.listToAttrs (
        map (skill: lib.nameValuePair skill.name "${ceSkillsPath}/${skill.source}") ceSkills
      );
      prompts = builtins.listToAttrs (
        map (
          skill:
          lib.nameValuePair skill.prompt.name {
            inherit (skill.prompt)
              argumentHint
              description
              ;
            skill = skill.name;
          }
        ) (lib.filter (skill: skill ? prompt) ceSkills)
      );
    };
    opencode.commands = builtins.listToAttrs (
      map (skill: lib.nameValuePair skill.opencodeCommand "${ceSkillsPath}/${skill.source}/SKILL.md") (
        lib.filter (skill: skill ? opencodeCommand) ceSkills
      )
    );
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
      "moonbit-practice@moonbit-practice" = true;
      "autofix-bot@claude-plugins-official" = true;
      "data@claude-plugins-official" = true;
      "clangd-lsp@claude-plugins-official" = true;
      "keel@keel" = true;
      "know@know" = true;
    }
    // compoundEngineering.claude.enabledPlugins
    // {
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
    };
    plugins = [ ../../config/knowledge/know/plugins/know ];
    marketplaces = {
      inherit claude-plugins-official kuu-marketplace;
      moonbit-practice = moonbit-practice-marketplace;
      keel = keel-marketplace;
      know = ../../config/knowledge/know;
    }
    // {
      "${compoundEngineering.claude.marketplaceName}" = compoundEngineering.claude.marketplaceSource;
    };
  };
in
{
  imports = [
    ./claude-code.nix
    ./codex.nix
    ./opencode.nix
    ./skills.nix
  ];

  _module.args = {
    inherit
      compoundEngineering
      dangerousBashPatterns
      mcpServers
      secretPathRules
      sharedClaudeCode
      sharedAgentPolicy
      trustedHttpDomains
      trustedReadPaths
      trustedWritePaths
      ;
  };
}
