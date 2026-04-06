{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "codedb";
  version = "0.2.54";

  src = fetchurl {
    url = "https://github.com/justrach/codedb/releases/download/v${version}/codedb-linux-x86_64";
    hash = "sha256-K9Yd+k5mDzlXZHLC1hg481m3BDRLgolRKhozQKP6Nhg=";
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/codedb
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/codedb --version >/dev/null
  '';

  meta = with lib; {
    description = "Code intelligence server for AI agents — structural indexing, trigram search, MCP native";
    homepage = "https://github.com/justrach/codedb";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "codedb";
  };
}
