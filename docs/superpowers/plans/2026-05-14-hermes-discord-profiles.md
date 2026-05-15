# Hermes Discord Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run two isolated Hermes Discord-facing profiles, `personal` and `work`, mapped to Dionysus and Apollo Discord bots.

**Architecture:** Keep the upstream `services.hermes-agent` container module as the Podman container anchor, then add two explicit profile gateway services. Nix activation creates each Hermes profile directory and profile `config.yaml`; agenix provides each profile Discord `.env` when the encrypted secret files exist. Codex OAuth remains per-profile runtime state created with `hermes auth add`.

**Tech Stack:** NixOS module config in `hosts/ryobox/default.nix`, upstream Hermes Agent, Podman, systemd, agenix, Discord bot gateway integration.

---

## File Structure

- Modify `hosts/ryobox/default.nix`
  - Add `hermesGatewayProfiles`, profile config generation, and profile bootstrap activation.
  - Add `hermes-gateway-personal` and `hermes-gateway-work` systemd services.
  - Conditionally register agenix secrets when the Discord env secret files exist.
- Modify `docs/hermes-discord-profiles.md`
  - Document encrypted env file shape and runtime checks.
- Modify `docs/agents/operating-principles.md`
  - Record that Hermes uses Discord profile gateways, managed runtime, and Nix/agenix profile setup.

## Runtime Shape

- `hermes-agent.service` remains the upstream Podman container anchor.
- `hermes-gateway-personal.service` runs:

```bash
podman exec --user hermes hermes-agent /data/current-package/bin/hermes --profile personal gateway run --replace
```

- `hermes-gateway-work.service` runs:

```bash
podman exec --user hermes hermes-agent /data/current-package/bin/hermes --profile work gateway run --replace
```

- The services keep managed mode. Do not clear `HERMES_MANAGED` for runtime services.
- The services use `ConditionPathExists` for `/var/lib/hermes/.hermes/profiles/<profile>/.env`, so they skip startup until the matching Discord agenix secret exists. A matching `.path` unit starts the gateway automatically when the `.env` appears later.

## Task 1: Nix Profile Gateways

**Files:**
- Modify: `hosts/ryobox/default.nix`

- [x] **Step 1: Add profile service helpers**

Add `hermesStateDir`, `hermesContainerName`, `hermesContainerHermesBin`, `hermesProfileSubdirs`, `hermesGatewayProfiles`, `hermesProfileConfigFiles`, and `mkHermesProfileGatewayService`.

- [x] **Step 2: Add optional agenix secrets**

Register `hermes-discord-personal-env` and `hermes-discord-work-env` only when the corresponding encrypted file exists.

- [x] **Step 3: Add activation bootstrap**

Create `/var/lib/hermes/.hermes/profiles/{personal,work}`, profile subdirectories, `config.yaml`, `.managed`, and profile `.env` when the age secrets exist.

- [x] **Step 4: Add systemd units**

Generate `hermes-gateway-personal.service` and `hermes-gateway-work.service` from `hermesGatewayProfiles`.

## Task 2: Verification

**Files:**
- No additional files modified.

- [x] **Step 1: Format Nix**

Run:

```bash
nixfmt hosts/ryobox/default.nix
```

Expected: command exits 0.

- [x] **Step 2: Verify service ExecStart**

Run:

```bash
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-gateway-personal".serviceConfig.ExecStart'
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-gateway-work".serviceConfig.ExecStart'
```

Expected:

```text
/nix/store/...-podman-.../bin/podman exec --user hermes hermes-agent /data/current-package/bin/hermes --profile personal gateway run --replace
/nix/store/...-podman-.../bin/podman exec --user hermes hermes-agent /data/current-package/bin/hermes --profile work gateway run --replace
```

- [x] **Step 3: Verify runtime services do not clear managed mode**

Run:

```bash
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-gateway-personal".serviceConfig.ExecStart' | rg -- '--env HERMES_MANAGED=' || true
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-gateway-work".serviceConfig.ExecStart' | rg -- '--env HERMES_MANAGED=' || true
```

Expected: no output.

- [x] **Step 4: Run flake check**

Run:

```bash
nix flake check
```

Expected: `all checks passed!`

## Task 3: Runtime Setup

**Files:**
- Create later: `secrets/hermes-discord-personal-env.age`
- Create later: `secrets/hermes-discord-work-env.age`

- [ ] **Step 1: Create Discord env secrets**

Each decrypted env file must contain:

```dotenv
DISCORD_BOT_TOKEN=replace-with-bot-token
DISCORD_ALLOWED_USERS=replace-with-your-discord-user-id
DISCORD_HOME_CHANNEL=replace-with-briefing-or-nudge-text-channel-id
```

- [ ] **Step 2: Log in to Codex per profile**

Each profile must run `hermes --profile <profile> auth add openai-codex --type oauth` inside the Hermes container. The resulting auth state stays in `/var/lib/hermes/.hermes/profiles/<profile>` as runtime state.

- [ ] **Step 3: Apply NixOS config**

Run:

```bash
sudo nixos-rebuild switch --flake .
```

Expected: activation creates profile directories and copies existing profile env secrets.

- [ ] **Step 4: Start services**

Run:

```bash
sudo systemctl start hermes-gateway-personal.service
sudo systemctl start hermes-gateway-work.service
```

Expected: services start when their `.env` files exist; otherwise systemd skips them due to `ConditionPathExists`. After `.env` files appear, `hermes-gateway-<profile>-env.path` starts the matching gateway automatically.

## Self-Review

- Spec coverage: Two profile gateways, managed runtime, Nix-created profile config, agenix-managed Discord env, and runtime Codex auth are covered.
- Placeholder scan: Replacement strings appear only inside documented `.env` examples and are not committed secrets.
- Type consistency: Nix names are consistent across code and docs.
