{
  config,
  pkgs,
  ...
}:

let
  dotfilesRoot = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles";
  dotConfigRoot = "${dotfilesRoot}/dot-config";
in
{
  home.packages = with pkgs; [
    zellij
  ];

  xdg.configFile = {
    "zellij".source = config.lib.file.mkOutOfStoreSymlink "${dotConfigRoot}/config/zellij";
  };
}
