{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  autoPatchelfHook,
  cairo,
  coreutils,
  cups,
  dbus,
  dpkg,
  expat,
  fetchurl,
  gdk-pixbuf,
  glib,
  gtk3,
  lib,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeWrapper,
  nspr,
  nss,
  pango,
  qt6,
  stdenv,
  systemdLibs,
  vulkan-loader,
  wrapGAppsHook3,
  writeShellApplication,
  xdg-utils,
  xz,
}:

let
  launcher = writeShellApplication {
    name = "chatgpt";
    runtimeInputs = [ coreutils ];
    text = builtins.readFile ./launcher.sh;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt";
  version = "26.901.51231";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${finalAttrs.version}_amd64.deb";
    hash = "sha256-YlgBiNh8PTqTadq3xztCqKMlGNTfii1brmRm3erFwF4=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    qt6.wrapQtAppsHook
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    qt6.qtbase
    stdenv.cc.cc.lib
    systemdLibs
    xz
  ];

  runtimeDependencies = [
    libGL
    libnotify
    libpulseaudio
    libsecret
    vulkan-loader
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
  ];

  dontWrapGApps = true;
  dontWrapQtApps = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" source
    runHook postUnpack
  '';

  sourceRoot = "source";

  # autoPatchelf moves PT_INTERP beyond detect-libc's 2 KiB scan. Keep the
  # replacement the same length so ASAR offsets stay valid.
  postPatch = ''
    grep -aFq 'const family = familySync();' usr/lib/chatgpt/resources/app.asar
    sed -i "s|const family = familySync();|const family = 'glibc'     ;|" usr/lib/chatgpt/resources/app.asar
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r usr/* "$out"

    rm -f "$out/lib/chatgpt/chrome-sandbox"
    rm -f "$out/lib/chatgpt/libqt5_shim.so"

    resources="$out/lib/chatgpt/resources"
    find "$resources" -type f -name '*.musl.node' -delete
    find "$resources" -type d -name prebuilds -print0 | while IFS= read -r -d "" prebuildsPath; do
      find "$prebuildsPath" -mindepth 1 -maxdepth 1 \
        ! -name '*linux-x64' \
        -exec rm -rf -- {} +
    done

    install -Dm755 ${lib.getExe launcher} "$out/bin/chatgpt"

    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail "Exec=chatgpt %U" "Exec=$out/bin/chatgpt %U"
    printf 'StartupWMClass=chatgpt\n' >> "$out/share/applications/chatgpt.desktop"

    if [[ -f "$out/share/pixmaps/chatgpt.png" ]]; then
      install -Dm644 "$out/share/pixmaps/chatgpt.png" \
        "$out/share/icons/hicolor/1024x1024/apps/chatgpt.png"
    fi

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/chatgpt" \
      "''${gappsWrapperArgs[@]}" \
      "''${qtWrapperArgs[@]}" \
      --set CHATGPT_APP_ROOT "$out/lib/chatgpt" \
      --set CHATGPT_VERSION ${lib.escapeShellArg finalAttrs.version} \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';

  meta = {
    description = "Desktop application for ChatGPT";
    homepage = "https://openai.com/chatgpt/desktop/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "chatgpt";
  };
})
