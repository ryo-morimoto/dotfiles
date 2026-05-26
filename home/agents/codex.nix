_: {
  programs.codex = {
    context = builtins.readFile ./_AGENTS.md;
    enable = true;
  };
}
