{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "rodney";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/simonw/rodney/releases/download/v${version}/rodney-linux-amd64.tar.gz";
    hash = "sha256-KU4mCqClcPSge77/GLzVw+VtIa1WH9EkFUpsUrkZmnU=";
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
    install -Dm755 rodney $out/bin/rodney
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/rodney --help >/dev/null
  '';

  meta = with lib; {
    description = "CLI tool for interacting with the web";
    homepage = "https://github.com/simonw/rodney";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "rodney";
  };
}
