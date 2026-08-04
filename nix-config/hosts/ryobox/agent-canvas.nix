{
  config,
  lib,
  pkgs,
  ...
}:

let
  image = "ghcr.io/openhands/agent-canvas:1.6.1";
  containerName = "agent-canvas";
  listenPort = 8000;
  serveHttpsPort = 8443;
  username = "ryo-morimoto";
  homeDir = "/home/${username}";
  openhandsDir = "${homeDir}/.openhands";

  # Run as the host user so subscription homes mount without copy/777/ACL.
  hostUser = config.users.users.${username};
  hostUid = toString hostUser.uid;
  hostGid = toString config.users.groups.${hostUser.group}.gid;

  projects = {
    "bookoff.app" = "${homeDir}/ghq/github.com/commercex-holdings/bookoff.app";
    "repository-zero" = "${homeDir}/ghq/github.com/ryo-morimoto/repository-zero";
    "dotfiles" = "${homeDir}/ghq/github.com/ryo-morimoto/dotfiles";
    "devflow" = "${homeDir}/ghq/github.com/ryo-morimoto/devflow";
  };

  projectVolumeFlags = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: path: "-v ${lib.escapeShellArg path}:/projects/${name}") projects
  );

  # Fail if a required host path is missing (no silent || true).
  requirePaths =
    lib.concatMapStrings
      (path: ''
        if [ ! -e ${lib.escapeShellArg path} ]; then
          echo "agent-canvas: required path missing: ${path}" >&2
          exit 1
        fi
      '')
      (
        [
          "${homeDir}/.claude"
          "${homeDir}/.codex/auth.json"
          "${homeDir}/.grok/auth.json"
          "${homeDir}/.grok/bin/grok"
          openhandsDir
        ]
        ++ lib.attrValues projects
      );

  writeEnv = pkgs.writeShellScript "agent-canvas-write-env" ''
    set -euo pipefail
    umask 077
    mkdir -p /run/agent-canvas

    api_key=$(cat ${config.age.secrets.agent-canvas-api-key.path})
    secret_key=$(cat ${config.age.secrets.agent-canvas-oh-secret-key.path})
    if [ -z "$api_key" ] || [ -z "$secret_key" ]; then
      echo "agent-canvas: empty age secret" >&2
      exit 1
    fi

    # printf (not heredoc): survives nixfmt and keeps docker --env-file valid.
    {
      printf 'LOCAL_BACKEND_API_KEY=%s\n' "$api_key"
      printf 'OH_SESSION_API_KEYS_0=%s\n' "$api_key"
      printf 'OH_SECRET_KEY=%s\n' "$secret_key"
      printf 'AUTOMATION_BASE_URL=http://127.0.0.1:%s\n' '${toString listenPort}'
      printf 'FILE_STORE=local\n'
      printf 'HOME=/home/openhands\n'
      printf 'GROK_HOME=/home/openhands/.grok\n'
    } > /run/agent-canvas/env
    chmod 600 /run/agent-canvas/env
  '';

  runContainer = pkgs.writeShellScript "agent-canvas-run" ''
    set -euo pipefail
    ${requirePaths}

    # Image must already be present. Updates are explicit (agent-canvas-update).
    if ! ${pkgs.docker}/bin/docker image inspect ${image} >/dev/null 2>&1; then
      echo "agent-canvas: image ${image} not found; run: docker pull ${image}" >&2
      exit 1
    fi

    ${pkgs.docker}/bin/docker rm -f ${containerName} >/dev/null 2>&1 || true

    # No XAI_API_KEY: Grok uses SuperGrok OIDC via mounted ~/.grok (subscription).
    # Host uid so ~/.claude ~/.codex ~/.grok mount without credential copies.
    ${pkgs.docker}/bin/docker run -d \
      --name ${containerName} \
      --restart unless-stopped \
      --user ${hostUid}:${hostGid} \
      -p 127.0.0.1:${toString listenPort}:8000 \
      --env-file /run/agent-canvas/env \
      -v ${lib.escapeShellArg openhandsDir}:/home/openhands/.openhands \
      -v ${lib.escapeShellArg "${homeDir}/.claude"}:/home/openhands/.claude:ro \
      -v ${lib.escapeShellArg "${homeDir}/.codex"}:/home/openhands/.codex \
      -v ${lib.escapeShellArg "${homeDir}/.grok"}:/home/openhands/.grok \
      ${projectVolumeFlags} \
      ${image}
  '';

  stopContainer = pkgs.writeShellScript "agent-canvas-stop" ''
    set -euo pipefail
    ${pkgs.docker}/bin/docker rm -f ${containerName} >/dev/null 2>&1 || true
  '';

  updateImage = pkgs.writeShellScript "agent-canvas-update" ''
    set -euo pipefail
    ${pkgs.docker}/bin/docker pull ${image}
    ${pkgs.systemd}/bin/systemctl restart agent-canvas.service
  '';

  applyServe = pkgs.writeShellScript "agent-canvas-serve-apply" ''
    set -euo pipefail
    # After tailscale-serve-reset + Caddy; do not call `tailscale serve reset`.
    ${pkgs.tailscale}/bin/tailscale serve \
      --bg \
      --yes \
      --https=${toString serveHttpsPort} \
      http://127.0.0.1:${toString listenPort}
  '';
in
{
  age.secrets = {
    agent-canvas-api-key = {
      file = ../../secrets/agent-canvas-api-key.age;
      mode = "0400";
    };
    agent-canvas-oh-secret-key = {
      file = ../../secrets/agent-canvas-oh-secret-key.age;
      mode = "0400";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${openhandsDir} 0755 ${username} users - -"
  ];

  systemd.services = {
    agent-canvas = {
      description = "OpenHands Agent Canvas (Docker ${image}; Grok SuperGrok ACP)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "docker.service"
        "network-online.target"
      ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      path = [
        pkgs.docker
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "120s";
        RuntimeDirectory = "agent-canvas";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = writeEnv;
        ExecStart = runContainer;
        ExecStop = stopContainer;
      };
    };

    # Explicit update path only — not on every boot/start.
    agent-canvas-update = {
      description = "Pull Agent Canvas image and restart service";
      path = [
        pkgs.docker
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = updateImage;
      };
    };

    agent-canvas-tailscale-serve = {
      description = "Apply Tailscale Serve for Agent Canvas on :${toString serveHttpsPort}";
      wantedBy = [ "multi-user.target" ];
      after = [
        "tailscaled.service"
        "tailscale-serve-reset.service"
        "caddy.service"
        "agent-canvas.service"
      ];
      requires = [
        "tailscaled.service"
        "agent-canvas.service"
      ];
      wants = [
        "caddy.service"
        "tailscale-serve-reset.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        # Keep the unit startable after every tailscale-serve-reset.
        RemainAfterExit = false;
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 30); do ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"tailscale not ready\" >&2; exit 1'";
        ExecStart = applyServe;
      };
    };
  };
}
