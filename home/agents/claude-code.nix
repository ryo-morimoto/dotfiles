{
  config,
  pkgs,
  compound-engineering-plugin,
  claude-plugins-official,
  kuu-marketplace,
  moonbit-practice-marketplace,
  keel-marketplace,
  ...
}:

{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    settings = {
      permissions.allow = [ "mcp__pencil" ];
      statusLine = {
        type = "command";
        command = "node /home/ryo-morimoto/.claude/hud/omc-hud.mjs";
      };
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
        "semgrep@claude-plugins-official" = true;
        "moonbit-practice@moonbit-practice" = true;
        "autofix-bot@claude-plugins-official" = true;
        "data@claude-plugins-official" = true;
        "clangd-lsp@claude-plugins-official" = true;
        "keel@keel" = true;
        "compound-engineering@every-marketplace" = true;
        "coding-tutor@every-marketplace" = true;
        "know@know" = true;
        # Explicitly disabled
        "superpowers@claude-plugins-official" = false;
        "frontend-design@claude-plugins-official" = false;
        "code-review@claude-plugins-official" = false;
        "security-guidance@claude-plugins-official" = false;
        "ralph-loop@claude-plugins-official" = false;
        "agent-sdk-dev@claude-plugins-official" = false;
        "gopls-lsp@claude-plugins-official" = false;
        "rust-analyzer-lsp@claude-plugins-official" = false;
        "plugin-dev@claude-plugins-official" = false;
      };
      autoUpdatesChannel = "stable";
      minimumVersion = "2.1.12";
      skipDangerousModePermissionPrompt = true;
    };

    memory.text = builtins.readFile ./_AGENTS.md;

    plugins = [
      ../../config/knowledge/know/plugins/know
    ];

    marketplaces = {
      inherit claude-plugins-official kuu-marketplace;
      moonbit-practice = moonbit-practice-marketplace;
      keel = keel-marketplace;
      every-marketplace = compound-engineering-plugin;
      know = ../../config/knowledge/know;
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
    # keel plugin: mutable symlink for live development
    ".claude/plugins/keel".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/keel";

    # Marketplace directories: Nix-managed symlinks so rebuild updates them
    ".claude/plugins/marketplaces/claude-plugins-official".source = claude-plugins-official;
    ".claude/plugins/marketplaces/kuu-marketplace".source = kuu-marketplace;
    ".claude/plugins/marketplaces/moonbit-practice".source = moonbit-practice-marketplace;
    ".claude/plugins/marketplaces/keel".source = keel-marketplace;
    ".claude/plugins/marketplaces/every-marketplace".source = compound-engineering-plugin;
    ".claude/plugins/marketplaces/know".source = ../../config/knowledge/know;
  };
}
