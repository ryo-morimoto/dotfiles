# Hermes Discord Dependencies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Hermes Discord profile gateways load the Discord adapter successfully in the NixOS-managed container.

**Architecture:** Use Hermes' NixOS module option `services.hermes-agent.extraDependencyGroups` instead of runtime `pip` installs. Upstream Hermes declares `discord.py[voice]` in the `messaging` optional dependency group, and the NixOS module resolves optional dependency groups into the sealed Python environment.

**Tech Stack:** NixOS module config in `hosts/ryobox/default.nix`, Hermes Agent NixOS module, Podman container backend, systemd.

---

## Source Notes

- Hermes docs say NixOS module users manage configuration declaratively in Nix, and CLI config commands are blocked in managed mode: <https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup/>
- Hermes docs describe `extraDependencyGroups` as the path for upstream `pyproject.toml` optional dependency groups.
- Upstream `pyproject.toml` declares `messaging = ["python-telegram-bot[webhooks]==22.6", "discord.py[voice]==2.7.1", ...]`.
- Upstream NixOS module overrides the package when `extraDependencyGroups` is non-empty.
- Current failure: `journalctl -u hermes-gateway-{personal,work}` reports `Discord: discord.py not installed`.

## File Structure

- Modify `hosts/ryobox/default.nix`
  - Ensure `services.hermes-agent.extraDependencyGroups` includes `messaging`.
  - Add per-profile `.path` units and `hermes-agent.service` install linkage so gateway start/restart follows the container service.
- Modify `docs/hermes-discord-profiles.md`
  - Record that Discord gateway support requires Hermes' `messaging` dependency group.
  - Replace removed `hermes login` commands with `hermes auth add openai-codex --type oauth`.
  - Add the missing `git add secrets/hermes-discord-*.age` step before `nixos-rebuild switch`.
  - Document automated gateway startup and restart behavior.

## Task 1: Enable Hermes Messaging Dependency Group

**Files:**
- Modify: `hosts/ryobox/default.nix`

- [ ] **Step 1: Add the dependency group**

Ensure this group is present inside `services.hermes-agent.extraDependencyGroups`:

```nix
"messaging"
```

Expected block:

```nix
hermes-agent = {
  enable = true;
  addToSystemPackages = true;
  extraDependencyGroups = [
    "messaging"
    "web"
    "pty"
  ];
  settings.model.provider = "openai-codex";
  container = {
    enable = true;
    backend = "podman";
    hostUsers = [ username ];
  };
};
```

- [ ] **Step 2: Format Nix**

## Task 1.5: Automate Gateway Start and Restart

**Files:**
- Modify: `hosts/ryobox/default.nix`

- [ ] **Step 1: Add profile env path units**

Add `mkHermesProfileGatewayPath` so systemd starts the matching gateway when the profile `.env` appears:

```nix
mkHermesProfileGatewayPath = profileName: profileConfig: {
  description = "${profileConfig.description} env watcher";
  wantedBy = [ "multi-user.target" ];
  wants = [ "hermes-agent.service" ];
  after = [ "hermes-agent.service" ];
  pathConfig = {
    PathExists = "${hermesStateDir}/.hermes/profiles/${profileName}/.env";
    Unit = "hermes-gateway-${profileName}.service";
  };
};
```

- [ ] **Step 2: Link gateway services to the container service**

Set each gateway service to be wanted by, bound to, and part of `hermes-agent.service`:

```nix
wantedBy = [
  "multi-user.target"
  "hermes-agent.service"
];
requires = [ "hermes-agent.service" ];
bindsTo = [ "hermes-agent.service" ];
partOf = [ "hermes-agent.service" ];
after = [ "hermes-agent.service" ];
```

- [ ] **Step 3: Generate path units**

Add:

```nix
systemd.paths = lib.mapAttrs' (
  profileName: profileConfig:
  lib.nameValuePair "hermes-gateway-${profileName}-env" (
    mkHermesProfileGatewayPath profileName profileConfig
  )
) hermesGatewayProfiles;
```

- [ ] **Step 4: Format Nix**

Run:

```bash
nixfmt hosts/ryobox/default.nix
```

Expected: exits 0.

## Task 2: Fix Hermes Discord Setup Docs

**Files:**
- Modify: `docs/hermes-discord-profiles.md`

- [ ] **Step 1: Document the git-add requirement**

After the `agenix -e ...` commands, document:

```bash
git add secrets/hermes-discord-personal-env.age secrets/hermes-discord-work-env.age
```

Reason: untracked files are not included in flake evaluation, so `builtins.pathExists`-guarded secrets will not be registered until the encrypted files are tracked.

- [ ] **Step 2: Replace removed login command**

Replace:

```bash
hermes --profile personal login --provider openai-codex
hermes --profile work login --provider openai-codex
```

with:

```bash
sudo podman exec --user hermes -it hermes-agent \
  /data/current-package/bin/hermes --profile personal auth add openai-codex --type oauth

sudo podman exec --user hermes -it hermes-agent \
  /data/current-package/bin/hermes --profile work auth add openai-codex --type oauth
```

- [ ] **Step 3: Document dependency expectation**

Add a short note:

```markdown
Discord support depends on Hermes' `messaging` optional dependency group. The NixOS config includes `messaging` in `services.hermes-agent.extraDependencyGroups`, which supplies `discord.py[voice]`.
```

- [ ] **Step 4: Document automated gateway lifecycle**

Add a short note that `hermes-gateway-<profile>.service` starts at boot when `.env` exists, `hermes-gateway-<profile>-env.path` starts it when `.env` appears later, and `hermes-agent.service` start/restart also starts/restarts the profile gateways.

## Task 3: Verify

**Files:**
- No additional files.

- [ ] **Step 1: Evaluate the NixOS module**

Run:

```bash
nix flake check
```

Expected: `all checks passed!`

- [ ] **Step 2: Rebuild and restart**

Run:

```bash
sudo nixos-rebuild switch --flake .
sudo systemctl restart hermes-agent.service
```

Expected: `hermes-agent.service` restarts and pulls both gateway services along.

- [ ] **Step 3: Confirm Discord adapter loads**

Run:

```bash
journalctl -u hermes-gateway-personal.service -n 80 --no-pager
journalctl -u hermes-gateway-work.service -n 80 --no-pager
```

Expected: logs do not contain:

```text
Discord: discord.py not installed
No adapter available for discord
```

## Commit

```bash
git add hosts/ryobox/default.nix docs/hermes-discord-profiles.md docs/superpowers/plans/2026-05-15-hermes-discord-dependencies.md
git commit -m "fix(hermes): include discord gateway dependencies"
```

## Self-Review

- Spec coverage: The plan addresses the observed `discord.py not installed` gateway failure, automated gateway lifecycle, and the two setup doc errors.
- Placeholder scan: No placeholders remain.
- Type consistency: Uses the upstream NixOS module option name `extraDependencyGroups` and upstream optional dependency group name `messaging`.
