{
  config,
  pkgs,
  compoundEngineering,
  claude-plugins-official,
  kuu-marketplace,
  moonbit-practice-marketplace,
  keel-marketplace,
  ...
}:

let
  claudeUserSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    statusLine = {
      type = "command";
      command = "node /home/ryo-morimoto/.claude/hud/omc-hud.mjs";
    };
    permissions.allow = [
      "Bash(git status*)"
      "Bash(git diff*)"
      "Bash(git log*)"
      "Bash(nixfmt *)"
      "Bash(nix flake check*)"
    ];
    autoUpdatesChannel = "stable";
    minimumVersion = "2.1.12";
    outputStyle = "default";
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
  };
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    settings = claudeUserSettings;

    memory.text = builtins.readFile ./_AGENTS.md;

    plugins = [
      ../../config/knowledge/know/plugins/know
    ];

    marketplaces = {
      inherit claude-plugins-official kuu-marketplace;
      moonbit-practice = moonbit-practice-marketplace;
      keel = keel-marketplace;
      know = ../../config/knowledge/know;
    }
    // {
      "${compoundEngineering.claude.marketplaceName}" = compoundEngineering.claude.marketplaceSource;
    };

    mcpServers = {
      exa = {
        command = "npx";
        args = [
          "-y"
          "exa-mcp-server"
        ];
        # EXA_API_KEY is loaded from agenix secret via shell session
      };
      vibe_kanban = {
        command = "npx";
        args = [
          "-y"
          "vibe-kanban@latest"
          "--mcp"
        ];
      };
      secretary = {
        type = "http";
        url = "https://secretary.ryo-morimoto-dev.workers.dev/mcp";
      };
    };

    # Skills managed by agent-skills-nix (see skills.nix)
  };

  home.file = {
    ".claude/settings.json".text = builtins.toJSON claudeUserSettings;

    # keel plugin: mutable symlink for live development
    ".claude/plugins/keel".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/keel";

    # Marketplace directories: Nix-managed symlinks so rebuild updates them
    ".claude/plugins/marketplaces/claude-plugins-official".source = claude-plugins-official;
    ".claude/plugins/marketplaces/kuu-marketplace".source = kuu-marketplace;
    ".claude/plugins/marketplaces/moonbit-practice".source = moonbit-practice-marketplace;
    ".claude/plugins/marketplaces/keel".source = keel-marketplace;
    ".claude/plugins/marketplaces/${compoundEngineering.claude.marketplaceName}".source =
      compoundEngineering.claude.marketplaceSource;
    ".claude/plugins/marketplaces/know".source = ../../config/knowledge/know;
  };
}
