{
  config,
  pencilMcp,
  ...
}:
let
  ghqDir = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto";
in
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
        "${ghqDir}/dotfiles".trust_level = "trusted";
        "${ghqDir}/newsfeed-ai".trust_level = "trusted";
        "${ghqDir}/ccinsights".trust_level = "trusted";
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
