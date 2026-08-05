{
  lib,
  ...
}:

{
  programs.obsidian = {
    enable = true;
    cli.enable = true;
    vaults.obsidian = {
      target = "obsidian";
      settings = {
        corePlugins = [
          {
            name = "daily-notes";
            enable = true;
          }
          {
            name = "backlink";
            enable = true;
          }
          {
            name = "outgoing-link";
            enable = true;
          }
          {
            name = "tag-pane";
            enable = true;
          }
          {
            name = "graph";
            enable = true;
          }
          {
            name = "global-search";
            enable = true;
          }
          {
            name = "command-palette";
            enable = true;
          }
          {
            name = "file-explorer";
            enable = true;
          }
          {
            name = "switcher";
            enable = true;
          }
          {
            name = "outline";
            enable = true;
          }
          {
            name = "templates";
            enable = true;
          }
          {
            name = "word-count";
            enable = true;
          }
          {
            name = "page-preview";
            enable = true;
          }
          {
            name = "note-composer";
            enable = true;
          }
          {
            name = "file-recovery";
            enable = true;
          }
        ];
      };
    };
  };

  # Vault templates and AGENTS.md are deployed by chezmoi (see dot-config/chezmoi/obsidian/)
  home.activation.initObsidianVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for dir in Daily Templates Attachments; do
      mkdir -p "$HOME/obsidian/$dir"
    done
  '';
}
