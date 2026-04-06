{
  lib,
  fetchFromGitHub,
  fetchurl,
  stdenvNoCC,
}:

let
  # pi-lens imports minimatch but doesn't declare it in package.json (upstream bug).
  # Bundle it here until upstream fixes their dependencies.
  minimatch = fetchurl {
    url = "https://registry.npmjs.org/minimatch/-/minimatch-10.2.4.tgz";
    hash = "sha256-idLEC0WWMmxQYdlaY6E8W3V/PgO8rSKatJamZzWSVSk=";
  };
  braceExpansion = fetchurl {
    url = "https://registry.npmjs.org/brace-expansion/-/brace-expansion-2.0.1.tgz";
    hash = "sha256-JGQSfaQdpQ35coHEzb7rZrNTyO69CcNVB7tknmbYAUE=";
  };
in

stdenvNoCC.mkDerivation rec {
  pname = "pi-lens";
  version = "2026-04-06";

  src = fetchFromGitHub {
    owner = "apmantza";
    repo = "pi-lens";
    rev = "7e8e083b6fa55f0276feb06a86da31395cebe67a";
    hash = "sha256-QEnvTEU/ZDlGiB3eTz4rXBl+iyL7zYRqMMYMFF3+DZY=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/pi/packages/${pname}
    cp -r . $out/share/pi/packages/${pname}

    # Install missing minimatch dependency and its transitive dep brace-expansion
    mkdir -p $out/share/pi/packages/${pname}/node_modules/minimatch
    tar xzf ${minimatch} --strip-components=1 -C $out/share/pi/packages/${pname}/node_modules/minimatch
    mkdir -p $out/share/pi/packages/${pname}/node_modules/brace-expansion
    tar xzf ${braceExpansion} --strip-components=1 -C $out/share/pi/packages/${pname}/node_modules/brace-expansion

    runHook postInstall
  '';

  meta = with lib; {
    description = "LSP, linter, and formatter integration for pi-coding-agent";
    homepage = "https://github.com/apmantza/pi-lens";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
