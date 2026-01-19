{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}:

stdenv.mkDerivation rec {
  pname = "vibe-kanban";
  version = "0.0.157";
  tag = "v${version}-20260119172005";

  src = fetchurl {
    url = "https://npm-cdn.vibekanban.com/binaries/${tag}/linux-x64/vibe-kanban.zip";
    sha256 = "1f66fr28xskwin75yi8fr28if65by9rmp9vmlpp82ihbp58jy9gv";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    install -Dm755 vibe-kanban $out/bin/vibe-kanban
  '';

  meta = with lib; {
    description = "Kanban board for AI coding agents";
    homepage = "https://github.com/BloopAI/vibe-kanban";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "vibe-kanban";
  };
}
