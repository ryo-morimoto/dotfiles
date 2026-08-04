{
  config,
  pkgs,
  ...
}:

let
  username = "ryo-morimoto";
  tld = "p.ryobox.xyz";
  certificate = ../../certs/portless-wildcard.crt;
in
{
  age.secrets.portless-tls-key = {
    file = ../../secrets/portless-tls-key.age;
    mode = "0400";
  };

  systemd.services.portless = {
    description = "Portless development reverse proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      PORTLESS_ASSUME_BIND_CAPABILITY = "1";
      PORTLESS_FLAT_WORKTREE = "1";
      PORTLESS_HTTPS = "1";
      PORTLESS_PORT = "443";
      PORTLESS_STATE_DIR = "/var/lib/portless";
      PORTLESS_SYNC_HOSTS = "0";
      PORTLESS_TLD = tld;
    };

    serviceConfig = {
      Type = "simple";
      User = username;
      Group = "users";
      UMask = "0077";

      StateDirectory = "portless";
      StateDirectoryMode = "0700";
      LoadCredential = "tls-key:${config.age.secrets.portless-tls-key.path}";

      ExecStart = "${pkgs.portless}/bin/portless proxy start --foreground --port 443 --https --tld ${tld} --cert ${certificate} --key %d/tls-key";
      Restart = "on-failure";
      RestartSec = "2s";

      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      NoNewPrivileges = true;

      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };
}
