{ pkgs, ... }:

{
  services = {
    postgresql.enable = true;

    forgejo = {
      enable = true;
      lfs.enable = true;

      database = {
        type = "postgres";
        createDatabase = true;
      };

      dump = {
        enable = true;
        interval = "daily";
        type = "zip";
        backupDir = "/var/lib/forgejo/dump";
      };

      settings = {
        server = {
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = 3000;
          DISABLE_SSH = true;
          START_SSH_SERVER = false;
        };

        service = {
          DISABLE_REGISTRATION = true;
        };

        repository = {
          DEFAULT_BRANCH = "main";
        };
      };
    };
  };

  # Resolve tailnet FQDN at service start, inject DOMAIN/ROOT_URL via env-to-ini.
  # Forgejo's environment-to-ini (run in nixpkgs preStart) overrides settings with
  # FORGEJO__SECTION__KEY env vars. Source: codeberg.org/forgejo/forgejo
  # contrib/environment-to-ini + nixos/modules/services/misc/forgejo.nix.
  systemd.services = {
    forgejo-tailnet-env = {
      description = "Resolve tailnet FQDN for Forgejo";
      wantedBy = [ "forgejo.service" ];
      before = [ "forgejo.service" ];
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "forgejo-tailnet-env" ''
          set -euo pipefail
          suffix=""
          for _ in $(seq 1 30); do
            suffix=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null \
              | ${pkgs.jq}/bin/jq -r '.CurrentTailnet.MagicDNSSuffix // empty') || true
            if [ -n "$suffix" ]; then break; fi
            sleep 2
          done
          if [ -z "$suffix" ]; then
            echo "tailnet not ready after 60s (is tailscaled logged in?)" >&2
            exit 1
          fi
          fqdn="ryobox.$suffix"
          install -m 0640 -o forgejo -g forgejo /dev/null /run/forgejo.env
          {
            echo "FORGEJO__SERVER__DOMAIN=$fqdn"
            echo "FORGEJO__SERVER__ROOT_URL=https://$fqdn/git/"
            echo "FORGEJO__SERVER__SSH_DOMAIN=$fqdn"
          } > /run/forgejo.env
        '';
      };
    };

    forgejo.serviceConfig.EnvironmentFile = "/run/forgejo.env";
  };
}
