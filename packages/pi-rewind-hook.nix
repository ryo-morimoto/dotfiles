{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "pi-rewind-hook";
  version = "2026-04-03";

  src = fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-rewind-hook";
    rev = "d5415335e7455b215987023631d6db07a79aed96";
    hash = "sha256-h2uSagCt73hIG6ysQJhsGDHVFSF71GQHEJ9PXk5ISsA=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/pi/packages/${pname}
    cp -r . $out/share/pi/packages/${pname}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Automatic git checkpoint and rewind extension for pi-coding-agent";
    homepage = "https://github.com/nicobailon/pi-rewind-hook";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
