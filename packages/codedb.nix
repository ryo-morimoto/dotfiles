{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "codedb";
  version = "0.2.53";

  src = fetchurl {
    url = "https://github.com/justrach/codedb/releases/download/v${version}/codedb-linux-x86_64";
    hash = "sha256-+2t/OEMIkyGZS19TgFJtEfwkDMdv02qA9cSY/BawIv4=";
  };

  dontUnpack = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/codedb
    runHook postInstall
  '';

  meta = with lib; {
    description = "Zig code intelligence server and MCP toolset for AI agents";
    homepage = "https://github.com/justrach/codedb";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "codedb";
  };
}
