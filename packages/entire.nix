{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.4.2";
  sources = {
    x86_64-linux = {
      asset = "entire_linux_amd64.tar.gz";
      hash = "sha256-B6QE3yftWHJXXxyyaUsGdt7Sm/fm23/zxP852oDcU+o=";
    };
    aarch64-linux = {
      asset = "entire_linux_arm64.tar.gz";
      hash = "sha256-ejvckdMlTo1gtDlnwjFNn4DkmPZ+6r4FCA9eMchCLlA=";
    };
  };

  sourceInfo =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system for entire: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "entire";
  inherit version;

  sourceRoot = ".";

  src = fetchurl {
    url = "https://github.com/entireio/cli/releases/download/v${version}/${sourceInfo.asset}";
    inherit (sourceInfo) hash;
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ./entire $out/bin/entire
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/entire version >/dev/null
  '';

  meta = with lib; {
    description = "CLI to capture and replay AI agent sessions in git workflows";
    homepage = "https://github.com/entireio/cli";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "entire";
  };
}
