{
  pencilMcp,
  ...
}:
{
  programs.codex = {
    custom-instructions = builtins.readFile ./_AGENTS.md;
    enable = true;
    # Uses pkgs.codex from nixpkgs (default)

    settings = {
      personality = "pragmatic";
      model = "gpt-5.3-codex";
      model_reasoning_effort = "xhigh";
      features.collab = true;
      projects = {
        "/home/ryo-morimoto/ghq/github.com/ryo-morimoto/dotfiles".trust_level = "trusted";
        "/home/ryo-morimoto/ghq/github.com/ryo-morimoto/newsfeed-ai".trust_level = "trusted";
        "/home/ryo-morimoto/ghq/github.com/ryo-morimoto/ccinsights".trust_level = "trusted";
      };
      mcp_servers.pencil = {
        command = toString pencilMcp;
        args = [
          "--app"
          "desktop"
        ];
      };
    };
  };
}
