{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "showboat";
  version = "0.6.1";

  src = fetchurl {
    url = "https://github.com/simonw/showboat/releases/download/v${version}/showboat-linux-amd64.tar.gz";
    hash = "sha256-RQkjgdZQel+xJ7iNvHnoiXB5M2T5XGyYFwBSbkd/t6E=";
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
    install -Dm755 showboat $out/bin/showboat
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/showboat --help >/dev/null
  '';

  meta = with lib; {
    description = "Create executable documents that demonstrate an agent's work";
    homepage = "https://github.com/simonw/showboat";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "showboat";
  };
}
