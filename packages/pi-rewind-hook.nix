{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "pi-rewind-hook";
  version = "2026-04-05";

  src = fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-rewind-hook";
    rev = "932be34c64d8dbf96ca107b074fee415c2750062";
    hash = "sha256-k+9WzXPuMkQlRSSbJ3vfnRrqs8j7A0V0M9Uf5iBFdHk=";
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
