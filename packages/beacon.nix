{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "beacon";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "monochromegane";
    repo = "beacon";
    rev = "v${version}";
    hash = "sha256-yMk0bNeAM4xrYQhPYPX+3cEymXI/4IaXfh5cXu9XuUs=";
  };

  vendorHash = "sha256-+xkpltfSRfFxbNb72hGj/kAdFeMn7rkCycvlfy8Cz48=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "CLI tool to track coding agent session states in tmux";
    homepage = "https://github.com/monochromegane/beacon";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "beacon";
  };
}
