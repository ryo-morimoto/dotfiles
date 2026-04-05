{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "soulforge";
  version = "2.4.0";

  src = fetchurl {
    url = "https://github.com/ProxySoul/soulforge/releases/download/v${version}/soulforge-${version}-linux-x64.tar.gz";
    hash = "sha256-MrtVSPWFqSUwyclqxHKorBe7/81D5bQtjeYrPeVwcxg=";
  };

  sourceRoot = "soulforge-${version}-linux-x64";

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 soulforge $out/bin/soulforge
    ln -s soulforge $out/bin/sf
    runHook postInstall
  '';

  meta = with lib; {
    description = "Graph-powered code intelligence with multi-agent AI";
    homepage = "https://github.com/ProxySoul/soulforge";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "soulforge";
  };
}
