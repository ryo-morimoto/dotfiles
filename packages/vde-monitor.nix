{
  lib,
  symlinkJoin,
  writeShellApplication,
  nodejs,
  tmux,
}:

let
  version = "0.9.1";

  mkBin =
    name:
    writeShellApplication {
      inherit name;
      runtimeInputs = [
        nodejs
        tmux
      ];
      text = ''
        exec npx --yes --package vde-monitor@${version} ${name} "$@"
      '';
    };
in
symlinkJoin {
  name = "vde-monitor-${version}";
  paths = [
    (mkBin "vde-monitor")
    (mkBin "vde-monitor-hook")
    (mkBin "vde-monitor-summary")
  ];

  meta = with lib; {
    description = "Monitor tmux/WezTerm coding sessions from a browser";
    homepage = "https://github.com/yuki-yano/vde-monitor";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "vde-monitor";
  };
}
