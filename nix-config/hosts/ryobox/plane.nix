{ config, pkgs, ... }:

let
  planeTag = "v1.3.0";
  listenHttpPort = 8090;
  minioAccessKey = "plane-minio";
  planeFqdn = "plane.ryobox.xyz";

  composeYml = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/makeplane/plane/${planeTag}/deployments/cli/community/docker-compose.yml";
    hash = "sha256-LHpVlWrpXMnGTOkWsYwfhevzoPwB3/6DSxJHuiZLxk0=";
  };

  overrideYml = pkgs.writeText "plane-override.yml" ''
    services:
      plane-db:
        volumes: !override
          - /var/lib/plane/postgres:/var/lib/postgresql/data
      plane-minio:
        volumes: !override
          - /var/lib/plane/minio:/export
      proxy:
        ports: !override
          - "127.0.0.1:${toString listenHttpPort}:80"
  '';

  planeStartPre = pkgs.writeShellScript "plane-start-pre" ''
    set -euo pipefail

    secret_key=$(cat "${config.age.secrets.plane-secret-key.path}")
    pg_pass=$(cat "${config.age.secrets.plane-postgres-password.path}")
    pg_pass_url=$(printf '%s' "$pg_pass" | ${pkgs.jq}/bin/jq -sRr @uri)
    minio_secret=$(cat "${config.age.secrets.plane-minio-secret-key.path}")

    umask 077
    cat > /run/plane/.env <<EOF
    APP_RELEASE=${planeTag}
    APP_DOMAIN=${planeFqdn}
    WEB_URL=https://${planeFqdn}
    CORS_ALLOWED_ORIGINS=https://${planeFqdn}

    SECRET_KEY=$secret_key
    LIVE_SERVER_SECRET_KEY=$secret_key

    POSTGRES_USER=plane
    POSTGRES_DB=plane
    POSTGRES_PASSWORD=$pg_pass
    DATABASE_URL=postgresql://plane:$pg_pass_url@plane-db/plane

    AWS_ACCESS_KEY_ID=${minioAccessKey}
    AWS_SECRET_ACCESS_KEY=$minio_secret
    AWS_S3_BUCKET_NAME=uploads
    AWS_S3_ENDPOINT_URL=http://plane-minio:9000
    USE_MINIO=1
    MINIO_ENDPOINT_SSL=0
    FILE_SIZE_LIMIT=5242880

    RABBITMQ_USER=plane
    RABBITMQ_PASSWORD=plane
    RABBITMQ_VHOST=plane
    AMQP_URL=amqp://plane:plane@plane-mq:5672/plane

    LISTEN_HTTP_PORT=${toString listenHttpPort}
    LISTEN_HTTPS_PORT=443
    SITE_ADDRESS=:80
    CERT_ACME_CA=https://acme-v02.api.letsencrypt.org/directory

    DEBUG=0
    GUNICORN_WORKERS=1
    API_KEY_RATE_LIMIT=60/minute
    EOF

    ln -sfn ${composeYml} /run/plane/docker-compose.yml
    ln -sfn ${overrideYml} /run/plane/docker-compose.override.yml
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/plane          0750 root root - -"
    "d /var/lib/plane/postgres 0700 root root - -"
    "d /var/lib/plane/minio    0750 root root - -"
  ];

  age.secrets = {
    plane-secret-key.file = ../../secrets/plane-secret-key.age;
    plane-postgres-password.file = ../../secrets/plane-postgres-password.age;
    plane-minio-secret-key.file = ../../secrets/plane-minio-secret-key.age;
  };

  systemd.services = {
    plane = {
      description = "Plane self-host via docker compose (pinned ${planeTag})";
      wantedBy = [ "multi-user.target" ];
      after = [
        "docker.service"
      ];
      requires = [
        "docker.service"
      ];
      path = [ pkgs.docker ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "600s";
        RuntimeDirectory = "plane";
        RuntimeDirectoryMode = "0700";
        WorkingDirectory = "/run/plane";
        ExecStartPre = planeStartPre;
        ExecStart = "${pkgs.docker}/bin/docker compose --project-name plane up -d --wait";
        ExecStop = "${pkgs.docker}/bin/docker compose --project-name plane down";
      };
    };
  };
}
