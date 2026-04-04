{
  config,
  lib ? null,
  compound-engineering-plugin ? null,
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
    vibe_kanban = {
      transport = "stdio";
      command = "npx";
      args = [
        "-y"
        "vibe-kanban@latest"
        "--mcp"
      ];
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
  ceWorkflowPrompts = [
    {
      prompt = "ce-brainstorm";
      skill = "ce:brainstorm";
      source = "ce-brainstorm";
      description = "Explore requirements and approaches before planning";
      argumentHint = "[feature idea or problem to explore]";
    }
    {
      prompt = "ce-compound";
      skill = "ce:compound";
      source = "ce-compound";
      description = "Document a recently solved problem to compound your team's knowledge";
      argumentHint = null;
    }
    {
      prompt = "ce-ideate";
      skill = "ce:ideate";
      source = "ce-ideate";
      description = "Discover high-impact project improvements through divergent ideation and adversarial filtering";
      argumentHint = "[feature, focus area, or constraint]";
    }
    {
      prompt = "ce-plan";
      skill = "ce:plan";
      source = "ce-plan";
      description = "Turn feature ideas into detailed implementation plans";
      argumentHint = "[optional: feature description, requirements doc path, plan path to deepen, or improvement idea]";
    }
    {
      prompt = "ce-review";
      skill = "ce:review";
      source = "ce-review";
      description = "Multi-agent code review before merging";
      argumentHint = "[blank to review current branch, or provide PR link]";
    }
    {
      prompt = "ce-work";
      skill = "ce:work";
      source = "ce-work";
      description = "Execute plans with worktrees and task tracking";
      argumentHint = "[Plan doc path or description of work. Blank to auto use latest plan doc]";
    }
  ];
  ceCodexSupplementalSkills = [
    {
      name = "feature-video";
      source = "feature-video";
    }
    {
      name = "resolve-pr-feedback";
      source = "resolve-pr-feedback";
    }
    {
      name = "test-browser";
      source = "test-browser";
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
        map (
          workflow: lib.nameValuePair workflow.skill "${ceSkillsPath}/${workflow.source}"
        ) ceWorkflowPrompts
        ++ map (
          skill: lib.nameValuePair skill.name "${ceSkillsPath}/${skill.source}"
        ) ceCodexSupplementalSkills
      );
      prompts = builtins.listToAttrs (
        map (
          workflow:
          lib.nameValuePair workflow.prompt {
            inherit (workflow)
              argumentHint
              description
              skill
              ;
          }
        ) ceWorkflowPrompts
      );
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
      sharedAgentPolicy
      trustedHttpDomains
      trustedReadPaths
      trustedWritePaths
      ;
  };
}
