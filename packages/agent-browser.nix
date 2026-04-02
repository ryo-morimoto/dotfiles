{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "agent-browser";
  version = "0.23.4";

  src = fetchurl {
    url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-linux-x64";
    hash = "sha256-wAwmRsDkg+VcP1yJPFCiBlIRGTpvnt1xgLvFtQsVUm0=";
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
    install -Dm755 $src $out/bin/agent-browser
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/agent-browser --help >/dev/null
  '';

  meta = with lib; {
    description = "Browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "agent-browser";
  };
}
