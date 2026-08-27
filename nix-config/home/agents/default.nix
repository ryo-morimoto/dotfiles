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
in
{
  home = {
    packages = [ devServerReaper ];

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
    services.penpot-mcp = {
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

    # AI agent が起動して放置した dev server(next dev / vite 等)を定期回収する。
    # 個別 tool の hook に依存しない最終防衛線。詳細は dev-server-reaper.sh 冒頭。
    services.dev-server-reaper = {
      Unit.Description = "Reap leftover dev servers started by AI agents";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe devServerReaper} orphans";
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
