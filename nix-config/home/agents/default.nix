{
  config,
  lib,
  pkgs,
  ...
}:

let
  dotfilesRoot = "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles";
  dotConfigRoot = "${dotfilesRoot}/dot-config";
  devServerReaper = pkgs.writeShellApplication {
    name = "dev-server-reaper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.procps
    ];
    text = builtins.readFile ./dev-server-reaper.sh;
  };
  orcaAppImage = "${config.home.homeDirectory}/Applications/orca-linux.AppImage";
  # Orca は起動時に ~/.local/bin/{orca,orca-ide} へ AppImage を直接 exec する wrapper を
  # 生成するが、NixOS では共有 lib が無く動かない。Orca は既存 path が symlink(non-Orca)なら
  # 上書きを拒否する(inspectAppImageWrapper -> conflict / dispatcher -> skipped-foreign)ので、
  # Home Manager が symlink で置く Nix 版 wrapper が恒久的に使われる。
  # appimage-run の unpack 済み dir を -w で直接起動し、stdout に余計な行を出さない(--json 用)。
  orcaCli = pkgs.writeShellApplication {
    name = "orca-ide";
    runtimeInputs = [
      pkgs.appimage-run
      pkgs.coreutils
    ];
    text = ''
      export APPIMAGE="''${ORCA_APPIMAGE:-${orcaAppImage}}"
      if [ ! -f "$APPIMAGE" ]; then
        echo "Orca AppImage not found at $APPIMAGE" >&2
        exit 1
      fi
      sha="$(sha256sum "$APPIMAGE" | cut -d' ' -f1)"
      appdir="''${XDG_CACHE_HOME:-$HOME/.cache}/appimage-run/$sha"
      [ -x "$appdir" ] || appimage-run -x "$appdir" "$APPIMAGE" >&2
      export ORCA_NODE_OPTIONS="''${NODE_OPTIONS-}"
      export ORCA_NODE_REPL_EXTERNAL_MODULE="''${NODE_REPL_EXTERNAL_MODULE-}"
      unset NODE_OPTIONS NODE_REPL_EXTERNAL_MODULE
      # CLI は Node として動き display 不要。stale な DISPLAY(sandbox 内 Xvfb 等)を継承すると
      # bwrap の bind mount で失敗するので外す(upstream の shim も DISPLAY= で起動している)。
      unset DISPLAY
      ELECTRON_RUN_AS_NODE=1 exec appimage-run -w "$appdir" -- -e \
        '(async()=>{try{const path=require("path");const appDir=process.env.APPDIR;if(!appDir){console.error("APPDIR is not set.");process.exit(1);}const cli=path.join(appDir,"resources","app.asar.unpacked","out","cli","index.js");await Promise.resolve(require(cli).main(process.argv.slice(1)));}catch(error){console.error(error&&error.stack?error.stack:String(error));process.exit(1);}})();' \
        -- "$@"
    '';
  };
in
{
  home = {
    packages = [ devServerReaper ];

    # Orca が生成する wrapper を Nix 版で置き換える。force で既存 regular file を上書きする。
    file = {
      ".local/bin/orca-ide" = {
        source = lib.getExe orcaCli;
        force = true;
      };
      ".local/bin/orca" = {
        source = lib.getExe orcaCli;
        force = true;
      };
      # Orca terminal は userData/linux-orca-cli-shim を PATH 先頭に挿す。shim が Nix store への
      # symlink だと Orca の書き換えが EROFS で失敗して shim 注入自体を諦め、~/.local/bin の
      # Nix 版 wrapper に fall back する。
      ".config/orca/linux-orca-cli-shim/orca" = {
        source = lib.getExe orcaCli;
        force = true;
      };
    };

    sessionVariables = {
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers.override {
        withFirefox = false;
        withWebkit = false;
      }}";
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      CHROME_PATH = lib.getExe pkgs.chromium;
      CLAUDE_CODE_NO_FLICKER = "1";
      CLAUDE_CODE_DISABLE_MOUSE = "1";
    };

    activation = {
      syncChezmoiConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${lib.getExe pkgs.chezmoi} apply --force
      '';

      installMiseTools = lib.hm.dag.entryAfter [ "syncChezmoiConfig" ] ''
        if [ -r "$HOME/.config/mise/config.toml" ]; then
          echo "Installing mise tools from ~/.config/mise/config.toml"
          ${lib.getExe pkgs.mise} install --yes || \
            echo "warning: mise install failed; retry with: mise install" >&2
        fi
      '';

      installApmConfig = lib.hm.dag.entryAfter [ "installMiseTools" ] ''
        if [ -r "$HOME/.apm/apm.yml" ]; then
          echo "Installing APM config from ~/.apm/apm.yml via mise-managed apm"
          cd "$HOME/.apm"
          PATH="${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.git
              pkgs.mise
              pkgs.nodejs
            ]
          }:$HOME/.local/share/mise/shims:$PATH" \
          ${lib.getExe pkgs.mise} exec -- apm install --global || \
            echo "warning: apm install failed; retry with: mise install && mise exec -- apm install --global" >&2
        fi
      '';
    };
  };

  programs = {
    opencode = {
      enable = true;
      settings.permission = "allow";
    };
  };

  systemd.user = {
    services = {
      # AI agent が起動して放置した dev server(next dev / vite 等)を定期回収する。
      # 個別 tool の hook に依存しない最終防衛線。詳細は dev-server-reaper.sh 冒頭。
      dev-server-reaper = {
        Unit.Description = "Reap leftover dev servers started by AI agents";
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe devServerReaper} orphans";
        };
      };
    };

    timers.dev-server-reaper = {
      Unit.Description = "Periodically reap leftover dev servers";
      Timer = {
        OnBootSec = "10min";
        OnUnitActiveSec = "15min";
        AccuracySec = "1min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  # Dotfiles under dot-config are deployed by chezmoi (see dot-config/chezmoi/)
  xdg.configFile."chezmoi/chezmoi.toml".text = ''
    sourceDir = "${dotConfigRoot}/chezmoi"
  '';
}
