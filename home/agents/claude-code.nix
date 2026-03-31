{
  config,
  ...
}:

let
  dotfilesPath = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles";
in
{
  programs.claude-code = {
    enable = true;
    # Uses pkgs.claude-code from nixpkgs (default)

    settings = {
      permissions.allow = [ "mcp__pencil" ];
      hooks = {
        PostToolUse = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "node ~/.claude/si/scripts/improvement-post-tool.mjs";
                timeout = 3000;
              }
            ];
          }
        ];
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "node ~/.claude/si/scripts/improvement-session-end.mjs";
                timeout = 10000;
              }
            ];
          }
        ];
        PreCompact = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "node ~/.claude/si/scripts/improvement-pre-compact.mjs";
                timeout = 5000;
              }
            ];
          }
        ];
      };
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
        "compound-engineering@every-marketplace" = true;
        "coding-tutor@every-marketplace" = true;
        "decomposition@kuu-marketplace" = true;
        "claude-md-management@claude-plugins-official" = true;
        "skill-creator@claude-plugins-official" = true;
        "coderabbit@claude-plugins-official" = true;
        "semgrep@claude-plugins-official" = true;
        "recore-api-explorer@agent-skills-marketplace" = true;
        "moonbit-practice@moonbit-practice" = true;
        "autofix-bot@claude-plugins-official" = true;
        "data@claude-plugins-official" = true;
        "clangd-lsp@claude-plugins-official" = true;
        "keel@keel" = true;
        "knowledge-management@knowledge-management" = true;
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
      extraKnownMarketplaces = {
        agent-skills-marketplace.source = {
          source = "git";
          url = "https://github.com/commercex-holdings/agent-skills.git";
        };
        moonbit-practice.source = {
          source = "github";
          repo = "mizchi/moonbit-practice";
        };
        keel.source = {
          source = "github";
          repo = "ryo-morimoto/keel";
        };
        kuu-marketplace.source = {
          source = "github";
          repo = "fumiya-kume/claude-code";
        };
        every-marketplace.source = {
          source = "github";
          repo = "EveryInc/compound-engineering-plugin";
        };
        knowledge-management.source = {
          source = "git-subdir";
          url = "https://github.com/ryo-morimoto/dotfiles.git";
          path = "config/knowledge/knowledge-management";
        };
      };
      autoUpdatesChannel = "stable";
      minimumVersion = "2.1.12";
      skipDangerousModePermissionPrompt = true;
    };

    memory.text =
      builtins.readFile ../../config/claude/CLAUDE.md
      + builtins.readFile ../../config/claude/CLAUDE.md.tmpl;

    plugins = [ ../../config/claude/plugins/lite-agents ];

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
    };

    # Skills managed by agent-skills-nix (see skills.nix)
  };

  home.file = {
    # Mutable symlinks (live editing without rebuild)
    ".claude/si/scripts".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/claude/si/scripts";
    ".claude/si/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/claude/si/skills";
    ".claude/statusline.sh".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/claude/statusline.sh";
    # keel plugin: mutable symlink for live development
    ".claude/plugins/keel".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/keel";
  };
}
