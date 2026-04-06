{
  fetchurl,
  lib,
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

  dontBuild = true;
  dontPatchELF = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 soulforge $out/bin/soulforge
    ln -s soulforge $out/bin/sf

    # Runtime assets expected under ~/.soulforge/ — symlinked by Home Manager
    mkdir -p $out/share/soulforge
    cp -r deps/native $out/share/soulforge/native
    cp -r deps/wasm $out/share/soulforge/wasm
    cp -r deps/workers $out/share/soulforge/workers
    cp -r deps/opentui-assets $out/share/soulforge/opentui-assets
    cp deps/init.lua $out/share/soulforge/init.lua

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
