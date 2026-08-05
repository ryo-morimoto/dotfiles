{
  pkgs,
  ...
}:

{
  # ~/.config/zellij is deployed by chezmoi (see dot-config/chezmoi/dot_config/)
  home.packages = with pkgs; [
    zellij
  ];
}
