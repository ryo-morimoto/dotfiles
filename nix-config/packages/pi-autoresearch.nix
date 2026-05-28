{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "pi-autoresearch";
  version = "2026-04-06";

  src = fetchFromGitHub {
    owner = "davebcn87";
    repo = "pi-autoresearch";
    rev = "a16920294eb59c07ee210ed6851bec54a994e212";
    hash = "sha256-8/Me+In7oOEAzLmtp9jMYFwJjrhj5xvUZRhvn6O7eSM=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/pi/packages/${pname}
    cp -r . $out/share/pi/packages/${pname}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Autonomous experiment loop package for pi-coding-agent";
    homepage = "https://github.com/davebcn87/pi-autoresearch";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
