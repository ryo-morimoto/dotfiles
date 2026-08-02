{ pkgs, ... }:

let
  imageVersion = "0.30.0";
  imageDigest = "sha256:46ca028e294bd728e8e930a28e887f640a8f2a9533cc283f79bcc6ab73d2ffd8";
  image = "grafana/otel-lgtm:${imageVersion}@${imageDigest}";
  containerName = "agent-observability";
  dataDir = "/var/lib/agent-observability";

  runContainer = pkgs.writeShellScript "agent-observability-run" ''
    set -euo pipefail

    if ! ${pkgs.docker}/bin/docker image inspect ${image} >/dev/null 2>&1; then
      echo "agent-observability: image ${image} not found" >&2
      echo "agent-observability: run: systemctl start agent-observability-update.service" >&2
      exit 1
    fi

    ${pkgs.docker}/bin/docker rm -f ${containerName} >/dev/null 2>&1 || true
    ${pkgs.docker}/bin/docker run -d \
      --name ${containerName} \
      --restart unless-stopped \
      -p 127.0.0.1:3300:3000 \
      -p 127.0.0.1:4317:4317 \
      -p 127.0.0.1:4318:4318 \
      -e GF_AUTH_ANONYMOUS_ENABLED=true \
      -e GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer \
      -e GF_AUTH_DISABLE_LOGIN_FORM=true \
      -e GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/otel-lgtm/agent-latency.json \
      -e GF_USERS_DEFAULT_THEME=dark \
      -e 'PROMETHEUS_EXTRA_ARGS=--storage.tsdb.retention.time=14d --enable-feature=otlp-deltatocumulative' \
      -v ${dataDir}:/data \
      -v ${./agent-observability/otelcol-config.yaml}:/otel-lgtm/otelcol-config.yaml:ro \
      -v ${./agent-observability/loki-config.yaml}:/otel-lgtm/loki-config.yaml:ro \
      -v ${./agent-observability/tempo-config.yaml}:/otel-lgtm/tempo-config.yaml:ro \
      -v ${./agent-observability/grafana/dashboards.yaml}:/otel-lgtm/grafana/conf/provisioning/dashboards/agent-observability.yaml:ro \
      -v ${./agent-observability/grafana/agent-latency.json}:/otel-lgtm/agent-latency.json:ro \
      ${image}

    for _ in $(${pkgs.coreutils}/bin/seq 1 90); do
      status=$(${pkgs.docker}/bin/docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
        ${containerName})
      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          ${pkgs.docker}/bin/docker logs --tail 100 ${containerName} >&2
          exit 1
          ;;
      esac
      ${pkgs.coreutils}/bin/sleep 1
    done

    echo "agent-observability: timed out waiting for container health" >&2
    ${pkgs.docker}/bin/docker logs --tail 100 ${containerName} >&2
    exit 1
  '';

  stopContainer = pkgs.writeShellScript "agent-observability-stop" ''
    set -euo pipefail
    ${pkgs.docker}/bin/docker rm -f ${containerName} >/dev/null 2>&1 || true
  '';

  updateImage = pkgs.writeShellScript "agent-observability-update" ''
    set -euo pipefail
    ${pkgs.docker}/bin/docker pull ${image}
    ${pkgs.systemd}/bin/systemctl restart agent-observability.service
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root - -"
  ];

  systemd.services = {
    agent-observability = {
      description = "Local Claude Code and Codex observability (Grafana LGTM ${imageVersion})";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      path = [
        pkgs.coreutils
        pkgs.docker
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "120s";
        ExecStart = runContainer;
        ExecStop = stopContainer;
      };
    };

    agent-observability-update = {
      description = "Pull the pinned Grafana LGTM image and restart agent observability";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      path = [
        pkgs.docker
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "600s";
        ExecStart = updateImage;
      };
    };
  };
}
