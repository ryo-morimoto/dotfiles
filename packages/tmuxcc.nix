{
  lib,
  rustPlatform,
  makeWrapper,
  tmux,
  tmuxcc-src,
}:

rustPlatform.buildRustPackage {
  pname = "tmuxcc";
  version = tmuxcc-src.shortRev or "unstable";

  src = tmuxcc-src;

  cargoHash = "sha256-84zvJDvhFdVbvBw+5JhM5TPdENYPyjt/n+wkw6jfyz4=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/tmuxcc \
      --prefix PATH : ${lib.makeBinPath [ tmux ]}
  '';

  meta = with lib; {
    description = "AI Agent Dashboard for tmux - Monitor Claude Code, OpenCode, Codex CLI, and Gemini CLI";
    homepage = "https://github.com/nyanko3141592/tmuxcc";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "tmuxcc";
  };
}
