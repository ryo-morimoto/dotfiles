{
  autoPatchelfHook,
  fetchzip,
  lib,
  stdenv,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "coderabbit";
  version = "0.4.0";

  src = fetchzip {
    url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-linux-x64.zip";
    hash = "sha256-vJu7oEgMdswEktEwpSfjiksuXooJJC3A5mXH3Q2l1Ng=";
    stripRoot = false;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 coderabbit $out/bin/coderabbit
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/coderabbit --help >/dev/null
  '';

  meta = with lib; {
    description = "AI code review CLI by CodeRabbit";
    homepage = "https://www.coderabbit.ai/cli";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "coderabbit";
  };
}
