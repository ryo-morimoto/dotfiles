{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "pi-agent-stuff";
  version = "2025-03-29";

  src = fetchFromGitHub {
    owner = "mitsuhiko";
    repo = "agent-stuff";
    rev = "80e1e96fa563ffc0c9d60422eac6dc9e67440385";
    hash = "sha256-JKMqt5ionfF/aBFTSQe9BD49wAErNtEnf3Mnekk3nzk=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/pi/packages/${pname}
    cp -r . $out/share/pi/packages/${pname}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Commands, skills, extensions, and themes for pi-coding-agent";
    homepage = "https://github.com/mitsuhiko/agent-stuff";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
