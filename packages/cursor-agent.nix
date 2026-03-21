{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "cursor-agent";
  version = "2026.03.20-44cb435";

  src = fetchurl {
    url = "https://downloads.cursor.com/lab/${version}/linux/x64/agent-cli-package.tar.gz";
    sha256 = "sha256-LkEVTm6sKqbmX08aI1a4kPiLwkvOx8pU0T0ORT8Cptw=";
  };

  sourceRoot = "dist-package";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    mkdir -p $out/lib/cursor-agent $out/bin

    cp -r . $out/lib/cursor-agent/

    # Create wrapper that sets up the environment
    makeWrapper $out/lib/cursor-agent/node $out/bin/agent \
      --add-flags "--use-system-ca $out/lib/cursor-agent/index.js" \
      --set CURSOR_INVOKED_AS "agent"

    # Also provide cursor-agent alias
    ln -s $out/bin/agent $out/bin/cursor-agent
  '';

  meta = with lib; {
    description = "Cursor Agent CLI - AI coding agent in the terminal";
    homepage = "https://cursor.com";
    platforms = [ "x86_64-linux" ];
  };
}
