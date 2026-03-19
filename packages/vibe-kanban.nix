{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}:

stdenv.mkDerivation rec {
  pname = "vibe-kanban";
  version = "0.1.30";
  tag = "v${version}-20260313160158";

  src = fetchurl {
    url = "https://npm-cdn.vibekanban.com/binaries/${tag}/linux-x64/vibe-kanban.zip";
    sha256 = "0cpj3lc81d829b02sav48swkwblnhfxmwqi9kn40mn669s6p0v5d";
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
