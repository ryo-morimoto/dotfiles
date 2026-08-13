{ pkgs, ... }:

{
  home.sessionVariables = {
    # Required so mise-installed zed (bundled libxkbcommon) finds keymap data on NixOS
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
  };

  programs = {
    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user.name = "ryo-morimoto";
        user.email = "ryo.morimoto.dev@gmail.com";
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        credential."https://github.com" = {
          helper = "!\"$HOME/ghq/github.com/ryo-morimoto/dotfiles/tools/gh-router/gh-router\" credential";
          useHttpPath = true;
        };
        merge.conflictstyle = "diff3";
        diff.colorMoved = "default";
        wt = {
          basedir = "../{gitroot}-wt";
        };
      };
    };

    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };
  };
}
