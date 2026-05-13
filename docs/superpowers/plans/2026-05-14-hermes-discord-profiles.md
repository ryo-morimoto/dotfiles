# Hermes Discord Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run two isolated Hermes Discord-facing profiles, `personal` and `work`, mapped to Dionysos and Apollo Discord bots.

**Architecture:** Keep the upstream `services.hermes-agent` container module as the Podman container anchor, then add two explicit systemd services that execute profile-scoped Hermes gateways inside that container. Runtime services remain NixOS-managed; profile setup commands temporarily clear `HERMES_MANAGED` only while writing profile config/auth state.

**Tech Stack:** NixOS module config in `hosts/ryobox/default.nix`, upstream Hermes Agent 0.13.0, Podman, systemd, Discord bot gateway integration.

---

## File Structure

- Modify `hosts/ryobox/default.nix`
  - Add `hermesStateDir`, `hermesContainerName`, `hermesContainerHermesBin`, `hermesGatewayProfiles`, and `mkHermesProfileGatewayService` in the existing `let` block.
  - Add `hermes-gateway-personal` and `hermes-gateway-work` systemd services.
- Do not modify Discord server state from Nix.
- Do not commit Discord bot tokens or user IDs.
- Do not modify unrelated staged or untracked files.

## Operational Boundaries

- Discord category access is enforced in Discord:
  - Apollo role can see only `work`.
  - Dionysos role can see only `personal`.
- Hermes profile access is enforced by separate profile directories:
  - `/var/lib/hermes/.hermes/profiles/work`
  - `/var/lib/hermes/.hermes/profiles/personal`
- The existing `hermes-agent.service` remains running as the container anchor. It must not be configured with Discord credentials.
- Runtime systemd services inherit managed mode from the container. This preserves the upstream NixOS safety guard now that the Web UI is not used.
- Interactive setup commands use `podman exec --env HERMES_MANAGED=` so `login --provider openai-codex` and `gateway setup` can write profile-local config and auth state.
- The two new services start only after their profile `.env` file exists, avoiding boot-time restart loops before Discord setup is completed.

## Task 1: Add Profile Gateway Service Definitions

**Files:**
- Modify: `hosts/ryobox/default.nix`

- [ ] **Step 1: Confirm the profile services do not exist yet**

Run:

```bash
nix eval .#nixosConfigurations.ryobox.config.systemd.services.hermes-gateway-personal.serviceConfig.ExecStart
```

Expected: FAIL with an attribute-missing error for `hermes-gateway-personal`.

- [ ] **Step 2: Add Hermes profile service helpers to the `let` block**

In `hosts/ryobox/default.nix`, after the existing `dotfilesDir` binding, add:

```nix
  hermesStateDir = "/var/lib/hermes";
  hermesContainerName = "hermes-agent";
  hermesContainerHermesBin = "/data/current-package/bin/hermes";
  hermesGatewayProfiles = {
    personal = {
      description = "Hermes Agent Gateway - personal Discord profile";
    };
    work = {
      description = "Hermes Agent Gateway - work Discord profile";
    };
  };
  mkHermesProfileGatewayService =
    profileName: profileConfig:
    {
      description = profileConfig.description;
      wantedBy = [ "multi-user.target" ];
      requires = [ "hermes-agent.service" ];
      bindsTo = [ "hermes-agent.service" ];
      after = [ "hermes-agent.service" ];
      unitConfig.ConditionPathExists = "${hermesStateDir}/.hermes/profiles/${profileName}/.env";

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.podman}/bin/podman exec --user hermes ${hermesContainerName} ${hermesContainerHermesBin} --profile ${profileName} gateway run --replace";
        Restart = "always";
        RestartSec = 5;
      };
    };
```

- [ ] **Step 3: Keep upstream managed mode intact**

Leave the existing `services.hermes-agent` block in place:

```nix
    hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      settings.model.provider = "openai-codex";
      container = {
        enable = true;
        backend = "podman";
        hostUsers = [ username ];
      };
    };
```

Do not add `container.extraOptions`, and do not remove `/var/lib/hermes/.hermes/.managed`.

- [ ] **Step 4: Add the two profile systemd services**

Replace the current systemd service assignment header:

```nix
  systemd.services = {
```

with:

```nix
  systemd.services = lib.mapAttrs' (
    profileName: profileConfig:
    lib.nameValuePair "hermes-gateway-${profileName}" (
      mkHermesProfileGatewayService profileName profileConfig
    )
  ) hermesGatewayProfiles // {
```

Keep the existing `dotfiles-pull` and `nixos-upgrade` service definitions inside the final attribute set.

- [ ] **Step 5: Format the Nix file**

Run:

```bash
nixfmt hosts/ryobox/default.nix
```

Expected: command exits 0.

- [ ] **Step 6: Verify the new systemd services evaluate**

Run:

```bash
nix eval --raw .#nixosConfigurations.ryobox.config.systemd.services.hermes-gateway-personal.serviceConfig.ExecStart
nix eval --raw .#nixosConfigurations.ryobox.config.systemd.services.hermes-gateway-work.serviceConfig.ExecStart
```

Expected output:

```text
/nix/store/...-podman-.../bin/podman exec --user hermes hermes-agent /data/current-package/bin/hermes --profile personal gateway run --replace
/nix/store/...-podman-.../bin/podman exec --user hermes hermes-agent /data/current-package/bin/hermes --profile work gateway run --replace
```

- [ ] **Step 7: Verify runtime services keep managed mode inherited**

Run:

```bash
nix eval --raw .#nixosConfigurations.ryobox.config.systemd.services.hermes-gateway-personal.serviceConfig.ExecStart | rg -- '--env HERMES_MANAGED=' || true
nix eval --raw .#nixosConfigurations.ryobox.config.systemd.services.hermes-gateway-work.serviceConfig.ExecStart | rg -- '--env HERMES_MANAGED=' || true
```

Expected: no output. The service should not clear `HERMES_MANAGED` at runtime.

- [ ] **Step 8: Run full flake verification**

Run:

```bash
nix flake check
```

Expected: `all checks passed!`

- [ ] **Step 9: Commit the Nix service definitions**

Run:

```bash
git add hosts/ryobox/default.nix
git commit -m "feat(hermes): add discord profile gateways"
```

Expected: one commit containing only `hosts/ryobox/default.nix`.

## Task 2: Deploy And Confirm Units Are Present

**Files:**
- No repository files modified.

- [ ] **Step 1: Apply the NixOS configuration**

Run:

```bash
sudo nixos-rebuild switch --flake .
```

Expected: rebuild completes successfully.

- [ ] **Step 2: Confirm the default container anchor is active**

Run:

```bash
systemctl is-active hermes-agent.service
```

Expected:

```text
active
```

- [ ] **Step 3: Confirm profile units exist**

Run:

```bash
systemctl status hermes-gateway-personal.service --no-pager
systemctl status hermes-gateway-work.service --no-pager
```

Expected before profile setup: each unit exists and is either inactive or skipped because its profile `.env` does not exist.

- [ ] **Step 4: Confirm dashboard service is still absent**

Run:

```bash
systemctl status hermes-agent-dashboard.service --no-pager
```

Expected: systemd reports the unit could not be found.

## Task 3: Bootstrap The Personal Profile For Dionysos

**Files:**
- Runtime only: `/var/lib/hermes/.hermes/profiles/personal/`
- No repository files modified.

- [ ] **Step 1: Create the personal profile inside the Hermes container**

Run:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes profile create personal
```

Expected: Hermes reports that profile `personal` exists or was created.

- [ ] **Step 2: Authenticate Codex for the personal profile**

Run:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile personal login --provider openai-codex
```

Expected: device-code auth completes and stores credentials under the `personal` profile.

- [ ] **Step 3: Configure Discord for the personal profile**

Run:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile personal gateway setup
```

Choose Discord in the setup menu and enter:

```text
Bot token: Dionysos bot token from Discord Developer Portal
Allowed user IDs or usernames: your Discord user ID
Home channel ID: personal briefing or nudge text channel ID
```

Expected: `/var/lib/hermes/.hermes/profiles/personal/.env` exists and contains Discord variables. Do not print the file contents.

- [ ] **Step 4: Add personal channel prompts**

Open the mutable profile config:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /bin/bash
```

Inside the container, edit:

```bash
nano /data/.hermes/profiles/personal/config.yaml
```

Ensure it contains this shape, replacing the channel IDs with copied Discord forum channel IDs:

```yaml
gateway:
  platforms:
    discord:
      channel_prompts:
        "SECRETARY_FORUM_CHANNEL_ID": "You are Dionysos operating in the personal secretary project context."
        "OKSSKOLTEN_FORUM_CHANNEL_ID": "You are Dionysos operating in the oksskolten project context."
        "GH_FLOW_FORUM_CHANNEL_ID": "You are Dionysos operating in the gh-flow project context."
        "NAWABARI_FORUM_CHANNEL_ID": "You are Dionysos operating in the nawabari project context."
        "GAME_SCOUT_FORUM_CHANNEL_ID": "You are Dionysos operating in the game-scout project context."
```

Expected: config saves successfully. If Hermes refuses to save because it is managed, confirm the command includes `--env HERMES_MANAGED=`.

- [ ] **Step 5: Start the personal gateway**

Run:

```bash
sudo systemctl reset-failed hermes-gateway-personal.service
sudo systemctl start hermes-gateway-personal.service
systemctl is-active hermes-gateway-personal.service
```

Expected:

```text
active
```

- [ ] **Step 6: Verify personal Discord behavior**

In Discord:

```text
ryo-agent → personal → secretary forum → create a test post → first message includes @Dionysos
```

Expected: Dionysos replies in the forum post thread.

## Task 4: Bootstrap The Work Profile For Apollo

**Files:**
- Runtime only: `/var/lib/hermes/.hermes/profiles/work/`
- No repository files modified.

- [ ] **Step 1: Create the work profile inside the Hermes container**

Run:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes profile create work
```

Expected: Hermes reports that profile `work` exists or was created.

- [ ] **Step 2: Authenticate Codex for the work profile**

Run:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile work login --provider openai-codex
```

Expected: device-code auth completes and stores credentials under the `work` profile.

- [ ] **Step 3: Configure Discord for the work profile**

Run:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile work gateway setup
```

Choose Discord in the setup menu and enter:

```text
Bot token: Apollo bot token from Discord Developer Portal
Allowed user IDs or usernames: your Discord user ID
Home channel ID: work briefing or nudge text channel ID
```

Expected: `/var/lib/hermes/.hermes/profiles/work/.env` exists and contains Discord variables. Do not print the file contents.

- [ ] **Step 4: Add work channel prompts**

Open the mutable profile config:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /bin/bash
```

Inside the container, edit:

```bash
nano /data/.hermes/profiles/work/config.yaml
```

Ensure it contains this shape, replacing the channel IDs with copied Discord forum channel IDs:

```yaml
gateway:
  platforms:
    discord:
      channel_prompts:
        "DEV_BOOKOFF_FORUM_CHANNEL_ID": "You are Apollo operating in the dev-bookoff work project context."
        "CMX_RESEARCH_FORUM_CHANNEL_ID": "You are Apollo operating in the cmx-research work project context."
```

Expected: config saves successfully. If Hermes refuses to save because it is managed, confirm the command includes `--env HERMES_MANAGED=`.

- [ ] **Step 5: Start the work gateway**

Run:

```bash
sudo systemctl reset-failed hermes-gateway-work.service
sudo systemctl start hermes-gateway-work.service
systemctl is-active hermes-gateway-work.service
```

Expected:

```text
active
```

- [ ] **Step 6: Verify work Discord behavior**

In Discord:

```text
ryo-agent → work → dev-bookoff forum → create a test post → first message includes @Apollo
```

Expected: Apollo replies in the forum post thread.

## Task 5: Verify Isolation And Failure Modes

**Files:**
- No repository files modified.

- [ ] **Step 1: Verify both profile services are active**

Run:

```bash
systemctl is-active hermes-gateway-personal.service hermes-gateway-work.service
```

Expected:

```text
active
active
```

- [ ] **Step 2: Verify each service uses the intended profile**

Run:

```bash
systemctl cat hermes-gateway-personal.service | rg -- '--profile personal'
systemctl cat hermes-gateway-work.service | rg -- '--profile work'
```

Expected: both commands print the matching `ExecStart` line.

- [ ] **Step 3: Verify Discord category isolation manually**

In Discord server settings, inspect bot roles:

```text
Apollo role:
  work category: View Channels = allowed
  personal category: View Channels = denied

Dionysos role:
  personal category: View Channels = allowed
  work category: View Channels = denied
```

Expected: Apollo cannot see personal channels; Dionysos cannot see work channels.

- [ ] **Step 4: Verify briefing and nudge do not create forum threads**

Send a test nudge from each bot by using its configured text channel as home channel.

Expected:

```text
personal briefing/nudge messages appear in personal text channels
work briefing/nudge messages appear in work text channels
no new forum post is created for briefing/nudge
```

- [ ] **Step 5: Check logs for auth or Discord permission failures**

Run:

```bash
journalctl -u hermes-gateway-personal.service -n 80 --no-pager
journalctl -u hermes-gateway-work.service -n 80 --no-pager
```

Expected: no repeating errors for `No Codex credentials stored`, Discord missing intents, missing message content intent, or missing channel permissions.

## Task 6: Commit Runtime Guidance Documentation

**Files:**
- Create: `docs/hermes-discord-profiles.md`

- [ ] **Step 1: Create operator documentation**

Create `docs/hermes-discord-profiles.md` with:

```markdown
# Hermes Discord Profiles

This machine runs two Discord-facing Hermes profiles:

- `personal`: Dionysos bot, visible only in the Discord `personal` category.
- `work`: Apollo bot, visible only in the Discord `work` category.

The NixOS system creates these services:

- `hermes-gateway-personal.service`
- `hermes-gateway-work.service`

The upstream `hermes-agent.service` remains the Podman container anchor. Do not add Discord credentials to the default profile.

## Runtime State

Profile state lives outside the repository:

- `/var/lib/hermes/.hermes/profiles/personal`
- `/var/lib/hermes/.hermes/profiles/work`

Discord bot tokens and Codex OAuth credentials are runtime secrets and must not be committed.

## Setup Commands

Create and configure the personal profile:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes profile create personal
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile personal login --provider openai-codex
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile personal gateway setup
sudo systemctl start hermes-gateway-personal.service
```

Create and configure the work profile:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes profile create work
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile work login --provider openai-codex
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile work gateway setup
sudo systemctl start hermes-gateway-work.service
```

## Checks

```bash
systemctl is-active hermes-gateway-personal.service hermes-gateway-work.service
journalctl -u hermes-gateway-personal.service -n 80 --no-pager
journalctl -u hermes-gateway-work.service -n 80 --no-pager
```

## Discord Rules

- Forum post equals one session.
- The first message in a new forum post must mention the bot.
- Briefing and nudge messages go to text channels, not forums.
- Discord category permissions enforce work/personal separation.
```

- [ ] **Step 2: Confirm the documentation has no secrets**

Run:

```bash
rg -n "Bot token|DISCORD_BOT_TOKEN|access_token|refresh_token|SECRETARY_FORUM_CHANNEL_ID|DEV_BOOKOFF_FORUM_CHANNEL_ID" docs/hermes-discord-profiles.md
```

Expected: the command may show example labels such as `Bot token` or symbolic channel ID labels, but no real token, real user ID, or real channel ID appears.

- [ ] **Step 3: Commit the documentation**

Run:

```bash
git add docs/hermes-discord-profiles.md
git commit -m "docs(hermes): document discord profile operation"
```

Expected: one commit containing only `docs/hermes-discord-profiles.md`.

## Self-Review

- Spec coverage: The plan creates two profile services, keeps profile state separate, supports Discord forum/text channel behavior, keeps tokens out of Git, and includes verification for service state and Discord permission boundaries.
- Placeholder scan: The only uppercase channel ID strings are intentional operator replacement labels in mutable runtime config examples; they are not repository code.
- Type consistency: Nix names are consistent across tasks: `hermesGatewayProfiles`, `mkHermesProfileGatewayService`, `hermes-gateway-personal`, and `hermes-gateway-work`.
- Scope check: Discord server/category creation remains manual because it is external state and because bot tokens must not enter the repository.
