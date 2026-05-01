{
  autoPatchelfHook,
  fetchurl,
  git,
  lib,
  makeWrapper,
  openssl,
  openssh,
  stdenv,
  stdenvNoCC,
  zlib,
}:

stdenvNoCC.mkDerivation rec {
  pname = "apm";
  version = "0.11.0";

  src = fetchurl {
    url = "https://github.com/microsoft/apm/releases/download/v${version}/apm-linux-x86_64.tar.gz";
    hash = "sha256-Fw8K16ucCK4ViALcs5VWpLbIb8uLLB56JckLwHeopuA=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    openssl
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/apm" "$out/bin"
    cp -R . "$out/lib/apm/"
    chmod +x "$out/lib/apm/apm"
    makeWrapper "$out/lib/apm/apm" "$out/bin/apm" \
      --prefix PATH : "${
        lib.makeBinPath [
          git
          openssh
        ]
      }"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/apm --version >/dev/null
  '';

  meta = with lib; {
    description = "Agent Package Manager for AI agent configuration";
    homepage = "https://github.com/microsoft/apm";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "apm";
  };
}
