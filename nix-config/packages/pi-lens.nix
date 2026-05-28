{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "pi-lens";
  version = "2026-04-06";

  src = fetchFromGitHub {
    owner = "apmantza";
    repo = "pi-lens";
    rev = "7e8e083b6fa55f0276feb06a86da31395cebe67a";
    hash = "sha256-QEnvTEU/ZDlGiB3eTz4rXBl+iyL7zYRqMMYMFF3+DZY=";
  };

  npmDepsHash = "sha256-lKVK3iMGADeI4c5PXuh5i6NuFS3fsVLs1RYRnpFpH5Q=";

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/pi/packages/${pname}
    cp -r . $out/share/pi/packages/${pname}
    runHook postInstall
  '';

  meta = with lib; {
    description = "LSP, linter, and formatter integration for pi-coding-agent";
    homepage = "https://github.com/apmantza/pi-lens";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
