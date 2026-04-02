{
  fetchurl,
  lib,
  makeWrapper,
  nodejs,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "portless";
  version = "0.9.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
    hash = "sha256-Yt8st/+WG8GirCbxH5klDfpNljqIxFf4xqG9W7bIVkI=";
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/portless $out/bin
    cp -r dist/* $out/lib/portless/
    makeWrapper ${nodejs}/bin/node $out/bin/portless \
      --add-flags "$out/lib/portless/cli.js"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/portless --help >/dev/null
  '';

  meta = with lib; {
    description = "Replace port numbers with stable, named .localhost URLs";
    homepage = "https://github.com/vercel-labs/portless";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = "portless";
  };
}
