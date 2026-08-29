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
  # Electron の single-instance lock は SIGKILL 後に残留し、lock 先 pid が死んでいても
  # Orca が「別 instance 稼働中」と誤検知して exit 3 で止まる。pid が生きていない場合だけ掃除する
  # 最終防衛線。通常停止は SIGTERM で Orca 自身が lock を解放する(KillMode=control-group)。
  orcaCleanLock = pkgs.writeShellApplication {
    name = "orca-clean-lock";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      dir="''${XDG_CONFIG_HOME:-$HOME/.config}/orca"
      [ -L "$dir/SingletonLock" ] || exit 0
      pid="$(readlink "$dir/SingletonLock" | sed 's/.*-//')"
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        exit 0
      fi
      echo "orca-clean-lock: removing stale singleton lock (pid $pid)"
      rm -f "$dir/SingletonLock" "$dir/SingletonCookie" "$dir/SingletonSocket"
    '';
  };
  # Orca は serve 起動時に ~/.local/bin/{orca,orca-ide} へ AppImage を直接 exec する wrapper を
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
      ELECTRON_RUN_AS_NODE=1 exec appimage-run -w "$appdir" -- -e \
        '(async()=>{try{const path=require("path");const appDir=process.env.APPDIR;if(!appDir){console.error("APPDIR is not set.");process.exit(1);}const cli=path.join(appDir,"resources","app.asar.unpacked","out","cli","index.js");await Promise.resolve(require(cli).main(process.argv.slice(1)));}catch(error){console.error(error&&error.stack?error.stack:String(error));process.exit(1);}})();' \
        -- "$@"
    '';
  };
  # bwrap(appimage-run)は SIGTERM を子へ転送せず、cgroup 一斉 SIGTERM では Electron が lock を
  # 解放する前に落ちる。Electron main(`--serve` を持つ唯一の process)だけに SIGTERM を送り、
  # 自前の graceful quit(SingletonLock 解放・Xvfb 停止)を待つ。残りは systemd の control-group kill。
  orcaServeStop = pkgs.writeShellApplication {
    name = "orca-serve-stop";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.procps
    ];
    text = ''
      cgroup="/sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)"
      target=""
      while read -r pid; do
        if tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q -- ' --serve '; then
          target="$pid"
          break
        fi
      done < "$cgroup/cgroup.procs"
      [ -n "$target" ] || exit 0
      kill -TERM "$target"
      for _ in $(seq 25); do
        kill -0 "$target" 2>/dev/null || exit 0
        sleep 1
      done
      echo "orca-serve-stop: pid $target did not exit within 25s; leaving it to systemd" >&2
    '';
  };
  # DISPLAY 未設定なら Orca 自身が PATH 上の Xvfb を起動・管理する(stale X lock の掃除込み)ので
  # xvfb-run を挟まない。exec chain を保って SIGTERM が Electron に届くようにする。
  orcaServe = pkgs.writeShellApplication {
    name = "orca-serve";
    runtimeInputs = [
      pkgs.appimage-run
      pkgs.tailscale
      pkgs.which
      pkgs.xorg-server
    ];
    text = ''
      addr="$(tailscale ip -4)"
      exec appimage-run "$ORCA_APPIMAGE" \
        serve --port 6768 --pairing-address "$addr" --json
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
    claude-code.enable = true;
    codex.enable = true;
    opencode = {
      enable = true;
      settings.permission = "allow";
    };
  };

  systemd.user = {
    services = {
      penpot-mcp = {
        Unit = {
          Description = "Penpot MCP server";
          After = [ "network.target" ];
        };
        Service = {
          Environment = "PNPM_CONFIG_DANGEROUSLY_ALLOW_ALL_BUILDS=true";
          ExecStart = "${pkgs.nodejs}/bin/npx -y @penpot/mcp@stable";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

      # Orca を headless runtime server として常駐させ、laptop / browser / mobile から
      # Tailscale 越しに使う。AppImage は Nix 外(~/Applications)で手動更新する。
      # Orca が ~/.claude/settings.json と ~/.codex/hooks.json に注入する hook は
      # `chezmoi re-add` で source に取り込む方針。
      orca-serve = {
        Unit = {
          Description = "Orca runtime server (headless)";
          After = [ "network-online.target" ];
          StartLimitIntervalSec = 300;
          StartLimitBurst = 5;
        };
        Service = {
          Environment = [
            "LIBGL_ALWAYS_SOFTWARE=1"
            "ORCA_APPIMAGE=${orcaAppImage}"
            # Chromium は xdg-desktop-portal 用に自身を `app-orca-<pid>.scope` へ移動する
            # (components/dbus/xdg/systemd.cc)。service の cgroup から脱走すると stop で
            # 止まらず orphan が port と profile lock を握り続けるので、唯一の guard である
            # この env で無効化する。Chromium 内で他の用途は無い。
            "FLATPAK_SANDBOX_DIR=/nonexistent"
          ];
          ExecStartPre = lib.getExe orcaCleanLock;
          ExecStart = lib.getExe orcaServe;
          ExecStop = lib.getExe orcaServeStop;
          # main PID は bwrap になり SIGTERM を転送しないため、ExecStop 後の残りは cgroup 全体を kill。
          KillMode = "control-group";
          TimeoutStopSec = 40;
          Restart = "on-failure";
          # exit 3 = 別 instance が同じ userData を使用中。自動再起動しない。
          RestartPreventExitStatus = 3;
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

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
