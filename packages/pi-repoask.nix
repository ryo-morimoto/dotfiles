{
  lib,
  repoask,
  fetchFromGitHub,
  stdenvNoCC,
  writeText,
}:

let
  repoaskSrc = fetchFromGitHub {
    owner = "ryo-morimoto";
    repo = "repoask";
    rev = "5a0ae26cccdeb0efd4eadb158bd4bff30936fc59";
    hash = "sha256-uiVb9wjpkrWzcioFzIuQI9Cc53qdajuFYlsePuNtv54=";
  };

  packageJson = writeText "package.json" (
    builtins.toJSON {
      name = "pi-repoask";
      version = "0.2.0";
      description = "Code understanding tool for pi — BM25 full-text search across any GitHub repository";
      keywords = [ "pi-package" ];
      license = "MIT";
      pi = {
        skills = [ "./skills" ];
      };
    }
  );
in
stdenvNoCC.mkDerivation {
  pname = "pi-repoask";
  version = "0.2.0";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/pi/packages/pi-repoask/skills/repoask
    cp ${packageJson} $out/share/pi/packages/pi-repoask/package.json
    cp ${repoaskSrc}/skills/repoask/SKILL.md $out/share/pi/packages/pi-repoask/skills/repoask/SKILL.md

    # Make repoask binary available via PATH
    mkdir -p $out/bin
    ln -s ${repoask}/bin/repoask $out/bin/repoask
    runHook postInstall
  '';

  meta = with lib; {
    description = "Code understanding tool package for pi-coding-agent";
    homepage = "https://github.com/ryo-morimoto/repoask";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
