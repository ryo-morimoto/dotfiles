{
  lib,
  rustPlatform,
  tmuxcc-src,
}:

rustPlatform.buildRustPackage {
  pname = "tmuxcc";
  version = tmuxcc-src.shortRev or "unstable";

  src = tmuxcc-src;

  cargoHash = "sha256-84zvJDvhFdVbvBw+5JhM5TPdENYPyjt/n+wkw6jfyz4=";

  meta = with lib; {
    description = "AI Agent Dashboard for tmux - Monitor Claude Code, OpenCode, Codex CLI, and Gemini CLI";
    homepage = "https://github.com/nyanko3141592/tmuxcc";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "tmuxcc";
  };
}
