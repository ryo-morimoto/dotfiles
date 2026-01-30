{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "claude-squad";
  version = "1.0.14";

  src = fetchFromGitHub {
    owner = "smtg-ai";
    repo = "claude-squad";
    rev = "v${version}";
    hash = "sha256-zh4vhZMtKbNT3MxNr18Q/3XC0AecFf5tOYIRT1aFk38=";
  };

  vendorHash = "sha256-BduH6Vu+p5iFe1N5svZRsb9QuFlhf7usBjMsOtRn2nQ=";

  ldflags = [
    "-s"
    "-w"
  ];

  # Tests require git in PATH
  doCheck = false;

  postInstall = ''
    mv $out/bin/claude-squad $out/bin/cs
  '';

  meta = with lib; {
    description = "Manage multiple AI terminal agents like Claude Code, Aider, Codex, OpenCode, and Amp";
    homepage = "https://github.com/smtg-ai/claude-squad";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "cs";
  };
}
