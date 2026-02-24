{
  autoPatchelfHook,
  lib,
  stdenv,
  stdenvNoCC,
  starlintLinuxBin,
  starlintDarwinArm64Bin,
}:

let
  version = "latest";
  srcForSystem =
    {
      x86_64-linux = starlintLinuxBin;
      aarch64-darwin = starlintDarwinArm64Bin;
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system for starlint: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "starlint";
  inherit version;

  src = srcForSystem;

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 starlint $out/bin/starlint
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/starlint --help >/dev/null
  '';

  meta = with lib; {
    description = "A linter for MoonBit language";
    homepage = "https://github.com/mizchi/starlint";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "starlint";
  };
}
