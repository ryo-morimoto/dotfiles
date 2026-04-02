{
  autoPatchelfHook,
  lib,
  stdenv,
  stdenvNoCC,
  starlintLinuxBin,
}:

stdenvNoCC.mkDerivation {
  pname = "starlint";
  version = "latest";

  src = starlintLinuxBin;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

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
    platforms = [ "x86_64-linux" ];
    mainProgram = "starlint";
  };
}
