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
    rev = "e3a5345b298a37511a6b49311dc8e5e76d84819a";
    hash = "sha256-+ueDcvDbutegmqBCrqN5A2UfZ2ZZUFLCf4SJRoClCmo=";
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
