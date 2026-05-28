{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "grepika";
  version = "0.2.2";

  src = fetchurl {
    url = "https://github.com/agentika-labs/grepika/releases/download/v${version}/grepika-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-UCYO6o+acdAAY6E0GNYlcfC/XHC69l6YN/OyR4Mo/mw=";
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 grepika $out/bin/grepika
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/grepika --help >/dev/null
  '';

  meta = with lib; {
    description = "Token-efficient code search for AI agents";
    homepage = "https://github.com/agentika-labs/grepika";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "grepika";
  };
}
