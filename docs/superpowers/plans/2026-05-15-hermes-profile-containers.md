# Hermes Profile Containers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run `dionysus` and `apollon` as separate Hermes runtime containers with separated profile state, workspaces, service-account boundaries, and dashboard/preview port ranges.

**Architecture:** Add two profile-specific Podman containers beside the existing shared Hermes runtime first, verify them with `nixos-rebuild test`, then retire the old `hermes-agent` runtime in a second phase. Reuse the existing personal/work agenix secret files for v0.1 to avoid a risky secret rename during the runtime migration. Dashboard ports are host-published and firewall-open only on `lo` and `tailscale0`; preview ranges stay loopback-only.

**Tech Stack:** NixOS modules, Podman, systemd, agenix, Hermes Agent, `nixfmt`, `nix eval --apply`, `nix build --dry-run`.

---

## Source Context

- Current `ryobox` Hermes setup uses one upstream `services.hermes-agent` container named `hermes-agent`.
- Current `personal` and `work` gateway services run inside that shared container via `podman exec --user hermes hermes-agent ... --profile <profile> gateway run --replace`.
- Current dashboard uses the shared container and exposes host port `9119`.
- Upstream `services.hermes-agent` is single-instance oriented and hard-codes service/container identity, so this plan creates a small local multi-profile module instead of trying to instantiate the upstream module twice.
- Upstream Hermes supports reading env files from `$HERMES_HOME/.env`; v0.1 must not inject service tokens into the container create environment.

## Reviewed Design Fixes

This plan incorporates the document-review findings:

- Do not retire the old shared Hermes runtime until the new containers pass smoke checks.
- Reuse existing `hermes-discord-personal-env.age` and `hermes-discord-work-env.age` in v0.1.
- Fail Nix evaluation if those secret files are missing.
- Do not use `--env-file` on `podman create`; only non-secret profile metadata goes into the container environment.
- Publish dashboard host ports and open them only on NixOS `lo` and `tailscale0` firewall interfaces.
- Keep preview ranges bound to `127.0.0.1` and open them only on the NixOS `lo` firewall interface.
- Recreate managed containers when image, tools, entrypoint, port mapping, or UID/GID identity changes.
- Run Hermes processes as a non-root `hermes` user inside the container.
- Remove old `systemd.paths` when retiring legacy gateway helpers.
- Use working `nix eval --apply` commands for service-existence checks.

## Port Allocation

| Purpose | Port(s) | Exposure |
|---|---:|---|
| legacy shared dashboard | 9119 | kept during Phase A, removed in Phase B |
| dionysus dashboard | 9120 | host port, firewall-open only on `lo` and `tailscale0` |
| apollon dashboard | 9130 | host port, firewall-open only on `lo` and `tailscale0` |
| dionysus app previews | 9200-9299 | host loopback only |
| apollon app previews | 9300-9399 | host loopback only |

## File Structure

- Create `hosts/ryobox/hermes-profiles.nix`
  - Owns profile container definitions, shared runtime tools, state directory setup, profile config files, agenix secret references, systemd container/gateway/dashboard services, and loopback port mappings.
- Modify `hosts/ryobox/default.nix`
  - Phase A: imports `./hermes-profiles.nix` while keeping the old upstream Hermes runtime active.
  - Phase B: disables the old upstream runtime and removes old gateway/dashboard/path units after smoke checks pass.
- Create `docs/hermes-profiles-v0.1.md`
  - Documents profile/container mapping, runtime layout, service boundaries, ports, staged rollout, lazy repo workflow, and verification commands.
- Modify `docs/hermes-discord-profiles.md`
  - Replaces the old shared `personal`/`work` profile description with a pointer to the new v0.1 doc.

## Task 1: Add Container-Separated Profile Module

**Files:**
- Create: `hosts/ryobox/hermes-profiles.nix`

- [ ] **Step 1: Create the Nix module**

Add `hosts/ryobox/hermes-profiles.nix`:

```nix
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

    export PATH="/tools/bin:$PATH"
    export HERMES_HOME="/data/.hermes"
    export HOME="/data/home"
    export MESSAGING_CWD="/workspace"

    if ! getent group ${hermesUser} >/dev/null; then
      groupadd -g "${hermesGid}" ${hermesUser}
    fi

    if ! id -u ${hermesUser} >/dev/null 2>&1; then
      useradd \
        -u "${hermesUid}" \
        -g "${hermesGid}" \
        -d "$HOME" \
        -s /tools/bin/bash \
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
      "$MESSAGING_CWD" \
      /cache

    chown -R "${hermesUid}:${hermesGid}" /data /workspace /cache

    exec setpriv \
      --reuid "${hermesUid}" \
      --regid "${hermesGid}" \
      --init-groups \
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

  mkSoul =
    profileName: profileConfig:
    pkgs.writeText "SOUL-${profileName}.md" ''
      # ${lib.toUpper profileName}

      This Hermes profile is for ${profileConfig.serviceBoundary} work.

      ## Runtime Boundary

      This profile runs in the ${profileName} container.

      Use only ${profileConfig.serviceBoundary} accounts, service tokens, memory, and workspace state.

      ## Development Core

      For software development:

      - Detect misunderstandings early.
      - Convert non-trivial work into acceptance criteria.
      - Inspect relevant repository context before editing.
      - Prefer small, reversible changes.
      - Run the fastest meaningful check early.
      - Report verified and unverified items explicitly.
      - Do not force global worktree or branch naming conventions from the profile.

      Branch names follow the target repository convention and describe the change.
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
          ;
        tools = "${hermesRuntimeTools}";
        entrypoint = "${hermesContainerEntrypoint}";
        dashboardPort = profileConfig.dashboardPort;
        previewPortStart = profileConfig.previewPortStart;
        previewPortEnd = profileConfig.previewPortEnd;
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
        install -m 0640 -o ${hermesUid} -g ${hermesGid} ${mkSoul profileName profileConfig} ${paths.workspaceDir}/SOUL.md
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
        ExecStart = "${pkgs.podman}/bin/podman exec --user ${hermesUser} ${paths.containerName} /tools/bin/hermes gateway run --replace";
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
        ExecStart = "${pkgs.podman}/bin/podman exec --user ${hermesUser} ${paths.containerName} /tools/bin/hermes dashboard --host 0.0.0.0 --port ${toString profileConfig.dashboardPort} --no-open --tui --insecure";
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

  networking.firewall.interfaces.lo.allowedTCPPorts =
    lib.mapAttrsToList (_profileName: profileConfig: profileConfig.dashboardPort) profileDefinitions;
  networking.firewall.interfaces.lo.allowedTCPPortRanges = lib.mapAttrsToList (
    _profileName: profileConfig: {
      from = profileConfig.previewPortStart;
      to = profileConfig.previewPortEnd;
    }
  ) profileDefinitions;
  networking.firewall.interfaces.tailscale0.allowedTCPPorts =
    lib.mapAttrsToList (_profileName: profileConfig: profileConfig.dashboardPort) profileDefinitions;

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
```

- [ ] **Step 2: Format the module**

Run:

```bash
nixfmt hosts/ryobox/hermes-profiles.nix
```

Expected: command exits 0.

- [ ] **Step 3: Commit**

```bash
git add hosts/ryobox/hermes-profiles.nix
git commit -m "feat(hermes): define profile containers"
```

## Task 2: Phase A Import Without Retiring Legacy Runtime

**Files:**
- Modify: `hosts/ryobox/default.nix`

- [ ] **Step 1: Import the profile module**

Change:

```nix
imports = [ ./hardware-configuration.nix ];
```

to:

```nix
imports = [
  ./hardware-configuration.nix
  ./hermes-profiles.nix
];
```

- [ ] **Step 2: Keep old `services.hermes-agent` enabled**

Leave the current `services.hermes-agent` block enabled in Phase A. The old `hermes-agent`, old `personal/work` gateways, and old `9119` dashboard stay available while the new containers are tested.

- [ ] **Step 3: Format modified Nix files**

Run:

```bash
nixfmt hosts/ryobox/default.nix hosts/ryobox/hermes-profiles.nix
```

Expected: command exits 0.

- [ ] **Step 4: Evaluate new profile service presence**

Run:

```bash
nix eval --json --apply 'services: services ? "hermes-container-dionysus"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-container-apollon"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-dionysus"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-apollon"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-dashboard-dionysus"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-dashboard-apollon"' '.#nixosConfigurations.ryobox.config.systemd.services'
```

Expected output for every command:

```json
true
```

- [ ] **Step 5: Verify legacy services still exist in Phase A**

Run:

```bash
nix eval --json --apply 'services: services ? "hermes-agent"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-agent-dashboard"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-personal"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-work"' '.#nixosConfigurations.ryobox.config.systemd.services'
```

Expected output for every command:

```json
true
```

- [ ] **Step 6: Verify dashboard ports are host-published and preview ranges are loopback-published in service text**

Run:

```bash
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-container-dionysus".preStart' | rg -- '--publish 0\\.0\\.0\\.0:9120:9120'
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-container-apollon".preStart' | rg -- '--publish 0\\.0\\.0\\.0:9130:9130'
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-container-dionysus".preStart' | rg -- '--publish 127\\.0\\.0\\.1:9200-9299:9200-9299'
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-container-apollon".preStart' | rg -- '--publish 127\\.0\\.0\\.1:9300-9399:9300-9399'
```

Expected: commands find host dashboard publish flags and loopback preview publish flags.

- [ ] **Step 7: Commit**

```bash
git add hosts/ryobox/default.nix hosts/ryobox/hermes-profiles.nix
git commit -m "feat(hermes): add staged profile containers"
```

## Task 3: Phase A Deploy And Smoke Test New Containers

**Files:**
- Verify deployed system only.

- [ ] **Step 1: Apply without making the generation default**

Run:

```bash
sudo nixos-rebuild test --flake .
```

Expected: command exits 0. The old generation remains available as the default boot generation.

- [ ] **Step 2: Check old and new services are active**

Run:

```bash
systemctl is-active hermes-agent.service hermes-agent-dashboard.service
systemctl is-active hermes-container-dionysus.service hermes-container-apollon.service
systemctl is-active hermes-dashboard-dionysus.service hermes-dashboard-apollon.service
```

Expected output:

```text
active
active
active
active
active
active
```

- [ ] **Step 3: Check container identities**

Run:

```bash
sudo podman ps --format '{{.Names}}' | rg '^hermes-(dionysus|apollon)$'
```

Expected output contains:

```text
hermes-dionysus
hermes-apollon
```

- [ ] **Step 4: Check non-secret profile env**

Run:

```bash
sudo podman exec hermes-dionysus printenv HERMES_PROFILE
sudo podman exec hermes-apollon printenv HERMES_PROFILE
```

Expected output:

```text
dionysus
apollon
```

- [ ] **Step 5: Check dashboard loopback reachability**

Run:

```bash
curl -I http://127.0.0.1:9120/
curl -I http://127.0.0.1:9130/
```

Expected: each command returns an HTTP response.

- [ ] **Step 6: Check host listeners and firewall boundaries**

Run:

```bash
ss -ltnp | rg '0\\.0\\.0\\.0:(9120|9130)'
nix eval --json '.#nixosConfigurations.ryobox.config.networking.firewall.interfaces.lo.allowedTCPPorts'
nix eval --json '.#nixosConfigurations.ryobox.config.networking.firewall.interfaces.tailscale0.allowedTCPPorts'
nix eval --json '.#nixosConfigurations.ryobox.config.networking.firewall.interfaces.lo.allowedTCPPortRanges'
```

Expected:

- `ss` finds dashboard listeners on `0.0.0.0:9120` and `0.0.0.0:9130`
- `lo.allowedTCPPorts` includes `9120` and `9130`
- `tailscale0.allowedTCPPorts` includes `9120` and `9130`
- `lo.allowedTCPPortRanges` includes `9200-9299` and `9300-9399`

- [ ] **Step 7: Check gateway services only after Discord tokens are present**

Run:

```bash
sudo grep -E '^DISCORD_BOT_TOKEN=.+' /var/lib/hermes-profiles/dionysus/data/.hermes/.env
sudo grep -E '^DISCORD_BOT_TOKEN=.+' /var/lib/hermes-profiles/apollon/data/.hermes/.env
systemctl is-active hermes-gateway-dionysus.service hermes-gateway-apollon.service
```

Expected:

- both `grep` commands find a non-empty token line
- both gateway services are `active`

- [ ] **Step 8: Check GitHub auth if tokens are provisioned**

Run:

```bash
sudo podman exec hermes-dionysus gh auth status
sudo podman exec hermes-apollon gh auth status
```

Expected:

- `hermes-dionysus` reports the personal GitHub account if `GH_TOKEN` or `GITHUB_TOKEN` is present in the personal env file.
- `hermes-apollon` reports the work GitHub account if `GH_TOKEN` or `GITHUB_TOKEN` is present in the work env file.
- Neither output exposes the other profile's token.

- [ ] **Step 9: Roll back immediately if Phase A fails**

If any required Phase A check fails, run:

```bash
sudo systemctl stop hermes-container-dionysus.service hermes-container-apollon.service || true
sudo podman rm -f hermes-dionysus hermes-apollon || true
sudo nixos-rebuild switch --rollback
```

Expected: old `hermes-agent.service`, `hermes-gateway-personal.service`, `hermes-gateway-work.service`, and `hermes-agent-dashboard.service` are restored.

## Task 4: Phase B Retire Shared Hermes Runtime

**Files:**
- Modify: `hosts/ryobox/default.nix`

- [ ] **Step 1: Remove old shared profile helper definitions**

Delete the old top-level `let` definitions for:

```text
hermesStateDir
hermesContainerName
hermesContainerHermesBin
hermesProfileSubdirs
hermesGatewayProfiles
hermesProfileConfigFiles
hermesProfilesWithSecrets
mkHermesProfileGatewayService
mkHermesProfileGatewayPath
```

- [ ] **Step 2: Change upstream Hermes service to package source only**

Replace the current `services.hermes-agent` block with:

```nix
hermes-agent = {
  enable = false;
  addToSystemPackages = false;
};
```

- [ ] **Step 3: Remove old shared agenix secret mapping**

In `age.secrets`, remove only the old attribute generation for:

```text
hermes-discord-personal-env
hermes-discord-work-env
```

Keep the encrypted files themselves in `secrets/`; v0.1 still uses them through the new secret attribute names `hermes-dionysus-env` and `hermes-apollon-env`.

- [ ] **Step 4: Remove old shared profile activation script**

Delete the full `system.activationScripts."hermes-discord-profiles"` assignment.

- [ ] **Step 5: Remove old shared gateway path units**

Delete the old `systemd.paths` block that creates `hermes-gateway-personal-env` and `hermes-gateway-work-env`.

- [ ] **Step 6: Replace old `systemd.services` merge**

Replace the old `systemd.services` expression that adds `hermes-gateway-personal`, `hermes-gateway-work`, and `hermes-agent-dashboard` with only the unrelated local services that remain in `default.nix`:

```nix
systemd.services = {
  "dotfiles-pull" = {
    description = "Pull latest dotfiles from GitHub";
    serviceConfig = {
      Type = "oneshot";
      User = username;
      WorkingDirectory = dotfilesDir;
      ExecStart = "${pkgs.git}/bin/git pull --ff-only";
    };
  };

  "nixos-upgrade" = {
    after = [ "dotfiles-pull.service" ];
    wants = [ "dotfiles-pull.service" ];
  };
};
```

- [ ] **Step 7: Remove legacy dashboard firewall port**

Change:

```nix
firewall.interfaces.tailscale0.allowedTCPPorts = [
  80
  443
  9119
];
```

to:

```nix
firewall.interfaces.tailscale0.allowedTCPPorts = [
  80
  443
];
```

Dashboard ports are opened on `lo` and `tailscale0` by `hosts/ryobox/hermes-profiles.nix`.

- [ ] **Step 8: Format modified Nix files**

Run:

```bash
nixfmt hosts/ryobox/default.nix hosts/ryobox/hermes-profiles.nix
```

Expected: command exits 0.

- [ ] **Step 9: Evaluate retired legacy service absence**

Run:

```bash
nix eval --json --apply 'services: services ? "hermes-agent-dashboard"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-personal"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-work"' '.#nixosConfigurations.ryobox.config.systemd.services'
```

Expected output for every command:

```json
false
```

- [ ] **Step 10: Evaluate old path unit absence**

Run:

```bash
nix eval --json --apply 'paths: paths ? "hermes-gateway-personal-env"' '.#nixosConfigurations.ryobox.config.systemd.paths'
nix eval --json --apply 'paths: paths ? "hermes-gateway-work-env"' '.#nixosConfigurations.ryobox.config.systemd.paths'
```

Expected output for both commands:

```json
false
```

- [ ] **Step 11: Evaluate legacy dashboard firewall removal**

Run:

```bash
nix eval --json '.#nixosConfigurations.ryobox.config.networking.firewall.interfaces.tailscale0.allowedTCPPorts'
```

Expected output includes `80`, `443`, `9120`, and `9130`, and does not include `9119`.

- [ ] **Step 12: Commit**

```bash
git add hosts/ryobox/default.nix hosts/ryobox/hermes-profiles.nix
git commit -m "refactor(hermes): retire shared profile runtime"
```

## Task 5: Add v0.1 Profile Documentation

**Files:**
- Create: `docs/hermes-profiles-v0.1.md`
- Modify: `docs/hermes-discord-profiles.md`

- [ ] **Step 1: Create v0.1 documentation**

Create `docs/hermes-profiles-v0.1.md`:

````markdown
# Hermes Profiles v0.1

## Profiles

- `dionysus`: personal/hobby
- `apollon`: work

## Model

Profile = dedicated Podman container
Project = remote repo, lazy cloned on demand
Session = Hermes-managed

The container is a credential/state/workspace boundary. It is not a strong sandbox for malicious repo code.

## Runtime Layout

Host:

```text
/var/lib/hermes-profiles/dionysus/
  data/.hermes/
  data/home/
  workspace/

/var/lib/hermes-profiles/apollon/
  data/.hermes/
  data/home/
  workspace/
```

Container:

```text
/data/.hermes
/data/home
/workspace
/cache
/tools/bin
```

## Secret Files

v0.1 intentionally reuses existing encrypted files:

| Profile | Secret file |
|---|---|
| dionysus | `secrets/hermes-discord-personal-env.age` |
| apollon | `secrets/hermes-discord-work-env.age` |

The new Nix module exposes them as:

| Profile | agenix attribute |
|---|---|
| dionysus | `hermes-dionysus-env` |
| apollon | `hermes-apollon-env` |

Do not copy tokens between profiles.

## Ports

| Profile | Dashboard | Preview Range |
|---|---:|---:|
| dionysus | `9120` on host, firewall-open only on `lo` and `tailscale0` | `127.0.0.1:9200-9299` |
| apollon | `9130` on host, firewall-open only on `lo` and `tailscale0` | `127.0.0.1:9300-9399` |

Dashboard is started with Hermes `--insecure`, so v0.1 relies on the NixOS firewall to expose dashboard ports only on `lo` and `tailscale0`.
Preview ranges remain loopback-only and are opened only on the `lo` interface.

Use Tailscale ACLs to limit which Tailnet identities can reach `9120` and `9130`.

## Staged Rollout

Phase A:

1. Add new `hermes-dionysus` and `hermes-apollon` containers.
2. Keep old `hermes-agent`, `personal`, `work`, and `9119` dashboard services active.
3. Run smoke checks against new containers.

Phase B:

1. Remove old shared gateway services and path units.
2. Disable old upstream `services.hermes-agent`.
3. Remove old `9119` firewall port.

Rollback:

```bash
sudo systemctl stop hermes-container-dionysus.service hermes-container-apollon.service || true
sudo podman rm -f hermes-dionysus hermes-apollon || true
sudo nixos-rebuild switch --rollback
```

## v0.1 Scope

Included:

- separate runtime containers
- separate secrets/auth state
- separate Honcho workspaces
- separate workspaces
- `gh` CLI based repo discovery
- lazy clone into `/workspace/repos/<owner>/<repo>`
- shared development core
- service account boundary policy

Excluded:

- project registry
- global worktree manager
- custom session DB
- session-based branch naming
- full Slack/Gateway setup beyond profile env injection
- automatic skill package sync
- repo-specific worktree setup in profile config

## Lazy Repo Workflow

Discover:

```bash
gh repo view OWNER/REPO --json nameWithOwner,sshUrl,defaultBranchRef,viewerPermission
gh repo list OWNER --limit 100 --json nameWithOwner,sshUrl,visibility,isPrivate
```

Clone:

```bash
mkdir -p /workspace/repos/OWNER
gh repo clone OWNER/REPO /workspace/repos/OWNER/REPO
```

Existing checkout:

```bash
cd /workspace/repos/OWNER/REPO
git status
git fetch --prune
```

Do not overwrite dirty work.

## Branch Naming

Branch names follow repo convention and describe the change.

Good:

- `fix/login-error`
- `feat/oauth-refresh`
- `chore/update-ci`
- `fix/123-login-error`

Avoid:

- session IDs
- Hermes profile names
- agent-specific internal names

## Repo Setup

If `AGENTS.md` exists, follow it.

If `AGENTS.md` does not exist:

1. Read `README.md`.
2. Inspect build files.
3. Infer setup/check commands.
4. State assumptions explicitly.

Do not create `AGENTS.md` unless asked.

## Operation Safety

Allowed automatically:

- read files
- search files
- `gh repo view/list`
- `gh issue/pr view/list`
- clone
- fetch
- run non-destructive checks

Allowed when the task clearly implies coding:

- create branch
- edit files
- run tests
- commit locally

Requires explicit user intent or confirmation:

- push branch
- create PR
- comment on issue/PR
- update Linear/Notion/Slack
- delete remote branch
- delete workspace with dirty or unpushed changes

## Checks

```bash
systemctl is-active hermes-container-dionysus.service hermes-container-apollon.service
systemctl is-active hermes-dashboard-dionysus.service hermes-dashboard-apollon.service
systemctl is-active hermes-gateway-dionysus.service hermes-gateway-apollon.service

sudo podman exec hermes-dionysus printenv HERMES_PROFILE
sudo podman exec hermes-apollon printenv HERMES_PROFILE

curl -I http://127.0.0.1:9120/
curl -I http://127.0.0.1:9130/

ss -ltnp | rg '127\.0\.0\.1:(9120|9130)'
ss -ltnp | rg '0\.0\.0\.0:(9120|9130)'
```
````

- [ ] **Step 2: Replace the old Discord profile doc with a migration pointer**

Replace `docs/hermes-discord-profiles.md` with:

```markdown
# Hermes Profile Containers

Hermes now runs `dionysus` and `apollon` as separate profile containers.

The old shared-container `personal` / `work` Discord profile gateway model has been superseded after the staged migration.

See [Hermes Profiles v0.1](./hermes-profiles-v0.1.md) for:

- profile/container mapping
- runtime state layout
- secret files
- dashboard and preview port ranges
- staged rollout and rollback
- lazy repo workflow
- operation safety rules
- verification commands
```

- [ ] **Step 3: Check Markdown whitespace**

Run:

```bash
git diff --check -- docs/hermes-profiles-v0.1.md docs/hermes-discord-profiles.md
```

Expected: no output and exit 0.

- [ ] **Step 4: Commit**

```bash
git add docs/hermes-profiles-v0.1.md docs/hermes-discord-profiles.md
git commit -m "docs(hermes): document profile containers"
```

## Task 6: Run Final Verification

**Files:**
- Verify: `hosts/ryobox/default.nix`
- Verify: `hosts/ryobox/hermes-profiles.nix`
- Verify: `docs/hermes-profiles-v0.1.md`
- Verify: `docs/hermes-discord-profiles.md`

- [ ] **Step 1: Format Nix files**

Run:

```bash
nixfmt hosts/ryobox/default.nix hosts/ryobox/hermes-profiles.nix
```

Expected: command exits 0.

- [ ] **Step 2: Evaluate profile services**

Run:

```bash
nix eval --json --apply 'services: services ? "hermes-container-dionysus"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-container-apollon"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-dionysus"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-apollon"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-dashboard-dionysus"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-dashboard-apollon"' '.#nixosConfigurations.ryobox.config.systemd.services'
```

Expected output for every command:

```json
true
```

- [ ] **Step 3: Evaluate retired legacy services after Phase B**

Run:

```bash
nix eval --json --apply 'services: services ? "hermes-agent-dashboard"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-personal"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'services: services ? "hermes-gateway-work"' '.#nixosConfigurations.ryobox.config.systemd.services'
nix eval --json --apply 'paths: paths ? "hermes-gateway-personal-env"' '.#nixosConfigurations.ryobox.config.systemd.paths'
nix eval --json --apply 'paths: paths ? "hermes-gateway-work-env"' '.#nixosConfigurations.ryobox.config.systemd.paths'
```

Expected output for every command:

```json
false
```

- [ ] **Step 4: Dry-run build the system closure**

Run:

```bash
nix build .#nixosConfigurations.ryobox.config.system.build.toplevel --dry-run
```

Expected: command exits 0. If binary cache, network, or unrelated dirty-tree issues prevent completion, record the exact error and still report the targeted `nix eval` results from Steps 2-3.

- [ ] **Step 5: Check Markdown whitespace**

Run:

```bash
git diff --check -- docs/hermes-profiles-v0.1.md docs/hermes-discord-profiles.md docs/superpowers/plans/2026-05-15-hermes-profile-containers.md
```

Expected: command exits 0 with no output.

- [ ] **Step 6: Final verification summary**

Prepare this table in the final response:

| Criterion | Verification | Result |
|---|---|---|
| dionysus container service exists | `nix eval --apply ... hermes-container-dionysus` | verified/unverified |
| apollon container service exists | `nix eval --apply ... hermes-container-apollon` | verified/unverified |
| old shared dashboard removed after Phase B | `nix eval --apply ... hermes-agent-dashboard` | verified/unverified |
| old gateway path units removed after Phase B | `nix eval --apply ... hermes-gateway-*-env` | verified/unverified |
| dashboard ports are Tailnet reachable and previews stay loopback | `ss -ltnp`, publish eval, `lo` firewall eval, and `tailscale0` firewall eval | verified/unverified |
| docs describe v0.1 scope | `docs/hermes-profiles-v0.1.md` review | verified/unverified |
| rollback path exists | Task 3 Step 9 and docs review | verified/unverified |

## Self-Review

### Spec Coverage

- Separate `dionysus` / `apollon` containers: Task 1, Task 2, Task 3.
- Separate secret/auth state: Task 1 reuses existing separated personal/work secret files with new profile-specific agenix attributes.
- Honcho workspace separation: Task 1 config and Task 5 docs.
- Port range safety: Task 1 dashboard Tailnet publish, preview loopback publish, Task 3 listener checks, Task 5 docs.
- Lazy repo workflow: Task 5 docs.
- No project registry/global worktree manager/session branch naming: Task 5 docs.
- Staged migration and rollback: Task 3 and Task 4.
- Verification commands: Task 2, Task 3, Task 4, Task 6.

### Placeholder Scan

The plan contains no `TBD`, no deferred implementation steps, and no references to undefined files.

### Type Consistency

Profile names are consistently `dionysus` and `apollon`. Service names are consistently:

- `hermes-container-<profile>`
- `hermes-gateway-<profile>`
- `hermes-dashboard-<profile>`

Dashboard ports are consistently `9120` and `9130`; preview ranges are consistently `9200-9299` and `9300-9399`.
