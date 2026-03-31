{
  config,
  pkgs,
  ...
}:

let
  dotfilesPath = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles";
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.llm-agents.claude-code;

    # Settings are managed via /etc/claude-code/managed-settings.json (NixOS module)
    # to avoid Claude Code overwriting the Nix store symlink on startup.
    # See: https://github.com/anthropics/claude-code/issues/15786

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
