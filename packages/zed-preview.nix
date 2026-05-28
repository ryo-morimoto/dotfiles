{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
  libGL,
  vulkan-loader,
  wayland,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "zed-preview";
  version = "1.5.3-pre";

  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${finalAttrs.version}/zed-linux-x86_64.tar.gz";
    hash = "sha256-bupvzFc1+5TYOJN4gec4sF2m9Z+K51dyRdry7aPUXB0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    alsa-lib
    libGL
    stdenv.cc.cc.lib
    vulkan-loader
    wayland
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a . "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Preview release channel of the Zed editor";
    homepage = "https://zed.dev";
    license = lib.licenses.gpl3Only;
    mainProgram = "zed";
    platforms = [ "x86_64-linux" ];
  };
})
