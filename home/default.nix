{ config, pkgs, ... }:

let
  dotfilesPath = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles";
in {
  home.username = "ryo-morimoto";
  home.homeDirectory = "/home/ryo-morimoto";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # User packages
  home.packages = with pkgs; [
    # Editor
    neovim

    # Terminal
    ghostty

    # CLI tools
    wget
    tree
    ripgrep
    fd

    # Nix tools
    nixfmt-rfc-style
    statix
    deadnix

    # Development
    ghq
    gh
    claude-code
  ];

  # Git
  programs.git = {
    enable = true;
    userName = "ryo-morimoto";
    userEmail = "ryo.morimoto.dev@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  # Zsh
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
    };
    shellAliases =
      let
        navigation = {
          ".." = "cd ..";
          "..." = "cd ../..";
        };
        git = {
          g = "git";
          gs = "git status";
          gd = "git diff";
          ga = "git add";
          gc = "git commit";
          gp = "git push";
          gl = "git pull";
        };
        modern = {
          ls = "eza --icons";
          ll = "eza -la --icons";
          la = "eza -a --icons";
          lt = "eza --tree --icons";
          cat = "bat";
          grep = "rg";
          find = "fd";
        };
      in
      navigation // git // modern;
    initExtra = ''
      # キーバインド (Emacs style)
      bindkey -e
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Fzf (fuzzy finder)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [ "--height 40%" "--reverse" "--border" ];
  };

  # Eza (modern ls)
  programs.eza = {
    enable = true;
    git = true;
    icons = "auto";
  };

  # Zoxide (smart cd)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Bat (cat with syntax highlighting)
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
    };
  };

  # Direnv (per-directory environment)
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Dotfiles (mkOutOfStoreSymlink for instant updates)
  xdg.configFile = {
    "ghostty".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/ghostty";
    "niri".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/niri";
    "hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/hypr";
  };
}
