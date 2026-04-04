{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "pi-autoresearch";
  version = "2025-03-25";

  src = fetchFromGitHub {
    owner = "davebcn87";
    repo = "pi-autoresearch";
    rev = "62feb2f46ef2a1b8e39af381b47acc4d7af42ca8";
    hash = "sha256-abER02Ed6c48Pny9jJ/BXEhF1jJ3J7tA0bMSGT62o60=";
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
