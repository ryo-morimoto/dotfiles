{
  config,
  lib,
  pkgs,
  ...
}:

let
  profileRoot = "/var/lib/hermes-profiles";
  profileCacheRoot = "/var/cache/hermes-profiles";

  hermesUser = "hermes";
  hermesUid = "1000";
  hermesGid = "1000";
  dashboardHost = "0.0.0.0";
  containerImage = "ubuntu:24.04";
  containerConfigVersion = 2;
  containerPath = "/tools/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";

  hermesRuntimePackage = config.services.hermes-agent.package.override {
    extraDependencyGroups = [
      "messaging"
      "web"
      "pty"
      "honcho"
    ];
  };

  hermesRuntimeTools = pkgs.buildEnv {
    name = "hermes-profile-runtime-tools";
    paths = with pkgs; [
      hermesRuntimePackage
      git
      gh
      jq
      curl
      nix
      direnv
      openssh
      ripgrep
      fd
      nodejs
      python3
      uv
      bashInteractive
      coreutils
      findutils
      gnugrep
      gnused
      shadow
      util-linux
    ];
    pathsToLink = [ "/bin" ];
  };

  hermesContainerEntrypoint = pkgs.writeShellScript "hermes-profile-container-entrypoint" ''
    set -eu

    export PATH="${containerPath}"
    export HERMES_HOME="/data/.hermes"
    export HOME="/data/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_CACHE_HOME="/cache/xdg"
    export MESSAGING_CWD="/workspace"

    if ! getent group "${hermesGid}" >/dev/null; then
      groupadd -g "${hermesGid}" ${hermesUser}
    fi

    if ! getent passwd "${hermesUid}" >/dev/null; then
      useradd \
        -u "${hermesUid}" \
        -g "${hermesGid}" \
        -d "$HOME" \
        -s /bin/bash \
        ${hermesUser}
    fi

    mkdir -p \
      "$HERMES_HOME" \
      "$HERMES_HOME/memories" \
      "$HERMES_HOME/sessions" \
      "$HERMES_HOME/skills" \
      "$HERMES_HOME/skins" \
      "$HERMES_HOME/logs" \
      "$HERMES_HOME/plans" \
      "$HERMES_HOME/cron" \
      "$HOME" \
      "$XDG_CONFIG_HOME" \
      "$XDG_DATA_HOME" \
      "$XDG_CACHE_HOME" \
      "$MESSAGING_CWD" \
      /cache

    chown -R "${hermesUid}:${hermesGid}" /data /workspace /cache

    exec setpriv \
      --reuid "${hermesUid}" \
      --regid "${hermesGid}" \
      --clear-groups \
      "$@"
  '';

  profileDefinitions = {
    dionysus = {
      description = "Hermes Dionysus personal/hobby profile";
      envSecretName = "hermes-dionysus-env";
      envSecretFile = ../../secrets/hermes-discord-personal-env.age;
      dashboardPort = 9120;
      previewPortStart = 9200;
      previewPortEnd = 9299;
      honchoWorkspace = "moriryo-personal";
      honchoAiPeer = "dionysus";
      serviceBoundary = "personal/hobby";
      useCases = [
        "exploration"
        "learning"
        "creative work"
        "personal development"
        "wall-bouncing"
        "experiments"
      ];
      style = [
        "Exploratory"
        "Constructively disagreeable"
        "Curious"
        "Comfortable with ambiguity"
        "Willing to generate alternative frames"
      ];
      behavior = [
        "Classify messy inputs before advising."
        "Surface hidden assumptions."
        "Offer outside-context perspectives."
        "Turn vague ideas into small experiments."
        "Avoid prematurely automating personal reflection loops."
      ];
    };

    apollon = {
      description = "Hermes Apollon work profile";
      envSecretName = "hermes-apollon-env";
      envSecretFile = ../../secrets/hermes-discord-work-env.age;
      dashboardPort = 9130;
      previewPortStart = 9300;
      previewPortEnd = 9399;
      honchoWorkspace = "moriryo-work";
      honchoAiPeer = "apollon";
      serviceBoundary = "work";
      useCases = [
        "coding-agent workflows"
        "project execution"
        "review"
        "QA"
        "GitHub / Linear / Notion / Slack work operations"
      ];
      style = [
        "Ordered"
        "Concise"
        "Evidence-first"
        "Scope-controlled"
        "Verification-oriented"
      ];
      behavior = [
        "Prefer clear plans and explicit completion conditions."
        "Keep changes minimal and auditable."
        "Prioritize risk reduction and reviewability."
        "Protect work/private context boundaries."
      ];
    };
  };

  mkProfilePaths =
    profileName:
    let
      stateDir = "${profileRoot}/${profileName}";
    in
    {
      inherit stateDir;
      dataDir = "${stateDir}/data";
      hermesHome = "${stateDir}/data/.hermes";
      homeDir = "${stateDir}/data/home";
      workspaceDir = "${stateDir}/workspace";
      cacheDir = "${profileCacheRoot}/${profileName}";
      containerName = "hermes-${profileName}";
    };

  mkProfileConfig =
    profileName: profileConfig:
    (pkgs.formats.yaml { }).generate "hermes-${profileName}-config.yaml" {
      model.provider = "openai-codex";
      platforms.discord = {
        enabled = true;
        extra.channel_prompts = { };
      };
      honcho = {
        workspace = profileConfig.honchoWorkspace;
        aiPeer = profileConfig.honchoAiPeer;
      };
    };

  mkSoulSeed =
    profileName: profileConfig:
    pkgs.writeText "SOUL-${profileName}-seed.md" ''
      # ${lib.toUpper profileName}

      This Hermes profile is for ${profileConfig.serviceBoundary} work.

      Use this profile for:

      ${lib.concatMapStringsSep "\n" (useCase: "- ${useCase}") profileConfig.useCases}

      ## Personality Policy

      Style:

      ${lib.concatMapStringsSep "\n" (style: "- ${style}") profileConfig.style}

      Behavior:

      ${lib.concatMapStringsSep "\n" (behavior: "- ${behavior}") profileConfig.behavior}

      ## Runtime Boundary

      This profile runs in the ${profileName} container.

      Use only ${profileConfig.serviceBoundary} accounts, service tokens, memory, and workspace state.

      ## Development Core

      Personality changes tone and exploration style, not development standards.

      For software development, always follow the shared development core:

      - Detect misunderstandings early.
      - Convert non-trivial work into acceptance criteria.
      - Inspect relevant repository context before editing.
      - Prefer small, reversible changes.
      - Run the fastest meaningful check early.
      - Report verified and unverified items explicitly.
      - Do not force global worktree or branch naming conventions from the profile.

      Do not weaken:

      - early mistake detection
      - spec-declared QA
      - verification honesty
      - scope control
      - fact / assumption / decision separation

      Branch names follow the target repository convention and describe the change.

      ## Service Boundary

      Use only ${profileConfig.serviceBoundary} services.
      Do not copy tokens across profiles.
      Do not store facts from another profile's account boundary in this profile's memory.
    '';

  mkProfileRuntimeEnv =
    profileName: profileConfig:
    pkgs.writeText "hermes-${profileName}-runtime.env" ''
      HERMES_PROFILE=${profileName}
      HERMES_HOME=/data/.hermes
      HOME=/data/home
      MESSAGING_CWD=/workspace
      HONCHO_WORKSPACE=${profileConfig.honchoWorkspace}
      HONCHO_AI_PEER=${profileConfig.honchoAiPeer}
    '';

  mkIdentityHash =
    profileName: profileConfig:
    builtins.hashString "sha256" (
      builtins.toJSON {
        inherit
          profileName
          containerImage
          dashboardHost
          hermesUid
          hermesGid
          containerConfigVersion
          containerPath
          ;
        tools = "${hermesRuntimeTools}";
        entrypoint = "${hermesContainerEntrypoint}";
        inherit (profileConfig)
          dashboardPort
          previewPortStart
          previewPortEnd
          ;
      }
    );

  mkWaitForContainer =
    profileName:
    let
      paths = mkProfilePaths profileName;
    in
    pkgs.writeShellScript "wait-for-${paths.containerName}" ''
      set -eu
      for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
        if [ "$(${pkgs.podman}/bin/podman inspect ${paths.containerName} --format '{{.State.Running}}' 2>/dev/null || true)" = "true" ]; then
          exit 0
        fi
        sleep 1
      done
      echo "${paths.containerName} did not become running" >&2
      exit 1
    '';

  mkContainerService =
    profileName: profileConfig:
    let
      paths = mkProfilePaths profileName;
      runtimeEnv = mkProfileRuntimeEnv profileName profileConfig;
      identityHash = mkIdentityHash profileName profileConfig;
    in
    {
      description = "${profileConfig.description} container";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "podman.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "podman.service" ];

      preStart = ''
        install -d -m 0750 -o ${hermesUid} -g ${hermesGid} ${paths.dataDir}
        install -d -m 0750 -o ${hermesUid} -g ${hermesGid} ${paths.hermesHome}
        install -d -m 0750 -o ${hermesUid} -g ${hermesGid} ${paths.homeDir}
        install -d -m 0750 -o ${hermesUid} -g ${hermesGid} ${paths.workspaceDir}
        install -d -m 0750 -o ${hermesUid} -g ${hermesGid} ${paths.cacheDir}

        install -m 0640 -o ${hermesUid} -g ${hermesGid} ${mkProfileConfig profileName profileConfig} ${paths.hermesHome}/config.yaml
        if [ ! -e ${paths.workspaceDir}/SOUL.md ]; then
          install -m 0640 -o ${hermesUid} -g ${hermesGid} ${mkSoulSeed profileName profileConfig} ${paths.workspaceDir}/SOUL.md
        fi
        install -m 0600 -o ${hermesUid} -g ${hermesGid} ${runtimeEnv} ${paths.hermesHome}/.env
        cat ${config.age.secrets.${profileConfig.envSecretName}.path} >> ${paths.hermesHome}/.env
        chown ${hermesUid}:${hermesGid} ${paths.hermesHome}/.env
        chmod 0600 ${paths.hermesHome}/.env

        cat > ${paths.hermesHome}/honcho.json <<'HONCHO_JSON'
        {
          "hosts": {
            "hermes.${profileName}": {
              "workspace": "${profileConfig.honchoWorkspace}",
              "aiPeer": "${profileConfig.honchoAiPeer}"
            }
          }
        }
        HONCHO_JSON
        chown ${hermesUid}:${hermesGid} ${paths.hermesHome}/honcho.json
        chmod 0600 ${paths.hermesHome}/honcho.json

        ln -sfn ${hermesRuntimePackage} ${paths.dataDir}/current-package
        ln -sfn ${hermesContainerEntrypoint} ${paths.dataDir}/current-entrypoint

        current_identity="$(${pkgs.podman}/bin/podman inspect ${paths.containerName} --format '{{ index .Config.Labels "dev.ryobox.hermes.identity" }}' 2>/dev/null || true)"
        if [ "$current_identity" != "${identityHash}" ]; then
          ${pkgs.podman}/bin/podman rm -f ${paths.containerName} >/dev/null 2>&1 || true
        fi

        if ! ${pkgs.podman}/bin/podman inspect ${paths.containerName} >/dev/null 2>&1; then
          ${pkgs.podman}/bin/podman create \
            --name ${paths.containerName} \
            --replace \
            --label dev.ryobox.hermes.identity=${identityHash} \
            --volume /nix/store:/nix/store:ro \
            --volume ${hermesRuntimeTools}:/tools:ro \
            --volume ${paths.dataDir}:/data:rw \
            --volume ${paths.workspaceDir}:/workspace:rw \
            --volume ${paths.cacheDir}:/cache:rw \
            --publish ${dashboardHost}:${toString profileConfig.dashboardPort}:${toString profileConfig.dashboardPort} \
            --publish 127.0.0.1:${toString profileConfig.previewPortStart}-${toString profileConfig.previewPortEnd}:${toString profileConfig.previewPortStart}-${toString profileConfig.previewPortEnd} \
            --env HERMES_PROFILE=${profileName} \
            --env HERMES_HOME=/data/.hermes \
            --env HOME=/data/home \
            --env XDG_CONFIG_HOME=/data/home/.config \
            --env XDG_DATA_HOME=/data/home/.local/share \
            --env XDG_CACHE_HOME=/cache/xdg \
            --env PATH=${containerPath} \
            --env MESSAGING_CWD=/workspace \
            --env HONCHO_WORKSPACE=${profileConfig.honchoWorkspace} \
            --env HONCHO_AI_PEER=${profileConfig.honchoAiPeer} \
            --env HERMES_UID=${hermesUid} \
            --env HERMES_GID=${hermesGid} \
            --entrypoint /data/current-entrypoint \
            ${containerImage} \
            sleep infinity
        fi
      '';

      script = ''
        exec ${pkgs.podman}/bin/podman start -a ${paths.containerName}
      '';

      preStop = ''
        ${pkgs.podman}/bin/podman stop -t 10 ${paths.containerName} || true
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 30;
      };
    };

  mkGatewayService =
    profileName: profileConfig:
    let
      paths = mkProfilePaths profileName;
    in
    {
      description = "${profileConfig.description} gateway";
      wantedBy = [ "multi-user.target" ];
      requires = [ "hermes-container-${profileName}.service" ];
      bindsTo = [ "hermes-container-${profileName}.service" ];
      partOf = [ "hermes-container-${profileName}.service" ];
      after = [ "hermes-container-${profileName}.service" ];

      serviceConfig = {
        Type = "simple";
        ExecStartPre = [
          "${mkWaitForContainer profileName}"
          "${pkgs.gnugrep}/bin/grep -Eq '^DISCORD_BOT_TOKEN=.+' ${paths.hermesHome}/.env"
        ];
        ExecStart = "${pkgs.podman}/bin/podman exec --user ${hermesUid}:${hermesGid} ${paths.containerName} /tools/bin/hermes gateway run --replace";
        Restart = "always";
        RestartSec = 5;
      };
    };

  mkDashboardService =
    profileName: profileConfig:
    let
      paths = mkProfilePaths profileName;
    in
    {
      description = "${profileConfig.description} dashboard";
      wantedBy = [ "multi-user.target" ];
      requires = [ "hermes-container-${profileName}.service" ];
      bindsTo = [ "hermes-container-${profileName}.service" ];
      partOf = [ "hermes-container-${profileName}.service" ];
      after = [ "hermes-container-${profileName}.service" ];

      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${mkWaitForContainer profileName}";
        ExecStart = "${pkgs.podman}/bin/podman exec --user ${hermesUid}:${hermesGid} ${paths.containerName} /tools/bin/hermes dashboard --host 0.0.0.0 --port ${toString profileConfig.dashboardPort} --no-open --tui --insecure";
        Restart = "always";
        RestartSec = 5;
      };
    };
in
{
  assertions = lib.mapAttrsToList (profileName: profileConfig: {
    assertion = builtins.pathExists profileConfig.envSecretFile;
    message = "Hermes ${profileName} requires ${toString profileConfig.envSecretFile}; v0.1 reuses existing personal/work agenix env files.";
  }) profileDefinitions;

  age.secrets = lib.mapAttrs' (
    _profileName: profileConfig:
    lib.nameValuePair profileConfig.envSecretName {
      file = profileConfig.envSecretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    }
  ) profileDefinitions;

  environment.systemPackages = [ hermesRuntimePackage ];

  networking.firewall.interfaces = {
    lo = {
      allowedTCPPorts = lib.mapAttrsToList (
        _profileName: profileConfig: profileConfig.dashboardPort
      ) profileDefinitions;
      allowedTCPPortRanges = lib.mapAttrsToList (_profileName: profileConfig: {
        from = profileConfig.previewPortStart;
        to = profileConfig.previewPortEnd;
      }) profileDefinitions;
    };

    tailscale0.allowedTCPPorts = lib.mapAttrsToList (
      _profileName: profileConfig: profileConfig.dashboardPort
    ) profileDefinitions;
  };

  systemd.services =
    (lib.mapAttrs' (
      profileName: profileConfig:
      lib.nameValuePair "hermes-container-${profileName}" (mkContainerService profileName profileConfig)
    ) profileDefinitions)
    // (lib.mapAttrs' (
      profileName: profileConfig:
      lib.nameValuePair "hermes-gateway-${profileName}" (mkGatewayService profileName profileConfig)
    ) profileDefinitions)
    // (lib.mapAttrs' (
      profileName: profileConfig:
      lib.nameValuePair "hermes-dashboard-${profileName}" (mkDashboardService profileName profileConfig)
    ) profileDefinitions);
}
