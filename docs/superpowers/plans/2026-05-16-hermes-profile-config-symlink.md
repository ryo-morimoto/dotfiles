# Hermes Profile Config Symlink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Hermes profile-owned `SOUL.md` and skills into mutable dotfiles config, then expose them inside each profile container through a narrow bind mount and stable symlinks.

**Architecture:** Nix keeps managing container boundaries, ports, secrets, generated `.env`, `config.yaml`, and `honcho.json`. Hermes-owned policy and skill state lives in `config/hermes/profiles/<profile>/` on the host, is bind-mounted as `/profile-config` in the matching container, and is reached through `/workspace/SOUL.md` and `$HERMES_HOME/skills` symlinks. The migration preserves existing runtime `SOUL.md`/skills before replacing runtime files with symlinks.

**Tech Stack:** NixOS module, systemd, Podman, Hermes Agent, agenix, shell preStart scripts.

---

## File Structure

- Create: `config/hermes/profiles/dionysus/SOUL.md`
  - Mutable source of truth for the Dionysus profile prompt.
- Create: `config/hermes/profiles/dionysus/skills/.gitkeep`
  - Tracks the mutable skills directory until Hermes creates real skills.
- Create: `config/hermes/profiles/apollon/SOUL.md`
  - Mutable source of truth for the Apollon profile prompt.
- Create: `config/hermes/profiles/apollon/skills/.gitkeep`
  - Tracks the mutable skills directory until Hermes creates real skills.
- Modify: `hosts/ryobox/hermes-profiles.nix`
  - Add host config path constants.
  - Add per-profile `profileConfigDir`.
  - Mount each profile config directory as `/profile-config`.
  - Migrate existing runtime files into config when config is missing.
  - Replace `/workspace/SOUL.md` and `$HERMES_HOME/skills` with container-valid symlinks.
- Modify: `docs/hermes-profiles-v0.1.md`
  - Document the config ownership model and verification commands.

## Design Decisions

- `config/hermes/profiles/<profile>` is intentionally outside `/nix/store`, so Hermes can edit `SOUL.md` and skills.
- The container sees only the matching profile directory as `/profile-config`; it does not mount the whole dotfiles repo.
- `/workspace/SOUL.md` is a symlink to `/profile-config/SOUL.md`, not to a host `/home/...` path, because the host path is not visible inside the container.
- `$HERMES_HOME/skills` is a symlink to `/profile-config/skills`, so skill creation and edits survive rebuilds and can be reviewed in git.
- Nix-generated `config.yaml`, `.env`, and `honcho.json` remain runtime files because they encode machine/profile wiring and secrets injection.

## Acceptance Criteria

- `config/hermes/profiles/dionysus/SOUL.md` and `config/hermes/profiles/apollon/SOUL.md` exist and contain the current runtime policy.
- Each profile container mounts only its own config directory to `/profile-config`.
- Inside `hermes-dionysus`, `/workspace/SOUL.md` resolves to `/profile-config/SOUL.md`.
- Inside `hermes-apollon`, `/workspace/SOUL.md` resolves to `/profile-config/SOUL.md`.
- Inside both containers, `$HERMES_HOME/skills` resolves to `/profile-config/skills`.
- Existing runtime `SOUL.md` and skills are copied into config or backed up before replacement.
- `nixfmt`, Nix parsing, and staged secret checks pass.

---

### Task 1: Add Mutable Profile Config Files

**Files:**
- Create: `config/hermes/profiles/dionysus/SOUL.md`
- Create: `config/hermes/profiles/dionysus/skills/.gitkeep`
- Create: `config/hermes/profiles/apollon/SOUL.md`
- Create: `config/hermes/profiles/apollon/skills/.gitkeep`

- [ ] **Step 1: Create the profile config directories**

Run:

```bash
mkdir -p \
  config/hermes/profiles/dionysus/skills \
  config/hermes/profiles/apollon/skills
```

Expected: command exits with status `0`.

- [ ] **Step 2: Copy current Dionysus SOUL into dotfiles config**

Create `config/hermes/profiles/dionysus/SOUL.md` with:

```markdown
# Dionysus

This Hermes profile is for personal/hobby work.

Use this profile for:

- exploration
- learning
- creative work
- personal development
- wall-bouncing
- experiments

## Personality Policy

Style:

- Exploratory
- Constructively disagreeable
- Curious
- Comfortable with ambiguity
- Willing to generate alternative frames

Behavior:

- Classify messy inputs before advising.
- Surface hidden assumptions.
- Offer outside-context perspectives.
- Turn vague ideas into small experiments.
- Avoid prematurely automating personal reflection loops.

## Runtime Boundary

This profile runs in the dionysus container.

Use only personal/hobby accounts, service tokens, memory, and workspace state.

## Development Core

Personality changes tone and profile style, not development standards.

For software development, always follow the shared development core:

Primary evaluation axes:

1. Early mistake detection
2. Spec-declared QA
3. Verification honesty

Core principles:

- Detect misunderstandings as early as possible.
- Convert non-trivial tasks into acceptance criteria.
- Inspect relevant project context before editing.
- Prefer small, reversible changes.
- Run the fastest meaningful check early.
- Separate facts, assumptions, and decisions.
- Report verified and unverified items explicitly.
- Do not claim completion without verification.
- Do not optimize speed by skipping QA.
- Prefer maintained upstream skills over custom skills.
- Use thin wrapper skills only for context injection and policy selection.

Do not weaken:

- early mistake detection
- spec-declared QA
- verification honesty
- scope control
- fact / assumption / decision separation

Workspace isolation is repo-owned: fresh clone, worktree, branch, or setup script.
Do not force global worktree or branch naming conventions from the profile.
Branch names follow the target repository convention and describe the change.

## Service Boundary

The active Hermes profile determines which external accounts may be used.

Use personal/hobby services only.

Before creating, updating, deleting, posting, commenting, pushing, or sending messages through an external service, verify:

- active profile
- target service
- target account/workspace/org
- operation type
- whether the operation belongs to this profile

GitHub operations:

- Prefer `gh` CLI.
- Use `GH_TOKEN` for `gh` CLI.
- Use `GITHUB_TOKEN` for API fallback.
- Before GitHub write operations, run `gh auth status` and `gh repo view OWNER/REPO --json nameWithOwner,viewerPermission,defaultBranchRef`.
- Do not assume organization-wide admin access from a member PAT.

Never:

- use work services from dionysus
- use personal services from apollon
- copy tokens between profiles
- send work content to personal channels
- store work facts in personal memory
- store personal facts in work memory
```

- [ ] **Step 3: Copy current Apollon SOUL into dotfiles config**

Create `config/hermes/profiles/apollon/SOUL.md` with:

```markdown
# Apollon

This Hermes profile is for work operations.

Use this profile for:

- coding-agent workflows
- project execution
- review
- QA
- GitHub / Linear / Notion / Slack work operations

## Personality Policy

Style:

- Ordered
- Concise
- Evidence-first
- Scope-controlled
- Verification-oriented

Behavior:

- Prefer clear plans and explicit completion conditions.
- Keep changes minimal and auditable.
- Prioritize risk reduction and reviewability.
- Protect work/private context boundaries.

## Runtime Boundary

This profile runs in the apollon container.

Use only work accounts, service tokens, memory, and workspace state.

## Development Core

Personality changes tone and profile style, not development standards.

For software development, always follow the shared development core:

Primary evaluation axes:

1. Early mistake detection
2. Spec-declared QA
3. Verification honesty

Core principles:

- Detect misunderstandings as early as possible.
- Convert non-trivial tasks into acceptance criteria.
- Inspect relevant project context before editing.
- Prefer small, reversible changes.
- Run the fastest meaningful check early.
- Separate facts, assumptions, and decisions.
- Report verified and unverified items explicitly.
- Do not claim completion without verification.
- Do not optimize speed by skipping QA.
- Prefer maintained upstream skills over custom skills.
- Use thin wrapper skills only for context injection and policy selection.

Do not weaken:

- early mistake detection
- spec-declared QA
- verification honesty
- scope control
- fact / assumption / decision separation

Workspace isolation is repo-owned: fresh clone, worktree, branch, or setup script.
Do not force global worktree or branch naming conventions from the profile.
Branch names follow the target repository convention and describe the change.

## Service Boundary

The active Hermes profile determines which external accounts may be used.

Use work services only.

Before creating, updating, deleting, posting, commenting, pushing, or sending messages through an external service, verify:

- active profile
- target service
- target account/workspace/org
- operation type
- whether the operation belongs to this profile

GitHub operations:

- Prefer `gh` CLI.
- Use `GH_TOKEN` for `gh` CLI.
- Use `GITHUB_TOKEN` for API fallback.
- Before GitHub write operations, run `gh auth status` and `gh repo view OWNER/REPO --json nameWithOwner,viewerPermission,defaultBranchRef`.
- Do not assume organization-wide admin access from a member PAT.

Never:

- use work services from dionysus
- use personal services from apollon
- copy tokens between profiles
- send work content to personal channels
- store work facts in personal memory
- store personal facts in work memory
```

- [ ] **Step 4: Track empty skills directories**

Run:

```bash
touch \
  config/hermes/profiles/dionysus/skills/.gitkeep \
  config/hermes/profiles/apollon/skills/.gitkeep
```

Expected: command exits with status `0`.

- [ ] **Step 5: Verify config files contain runtime policy markers**

Run:

```bash
for profile in dionysus apollon; do
  rg -n 'Development Core|Service Boundary|Spec-declared QA|Before creating|Do not assume organization-wide admin access' \
    "config/hermes/profiles/$profile/SOUL.md"
done
```

Expected: each profile prints all five markers.

- [ ] **Step 6: Commit**

Run:

```bash
git add config/hermes/profiles
git commit -m "feat(hermes): add mutable profile config"
```

Expected: commit succeeds.

---

### Task 2: Add Profile Config Bind Mounts and Symlink Migration

**Files:**
- Modify: `hosts/ryobox/hermes-profiles.nix`

- [ ] **Step 1: Add config path constants**

In `hosts/ryobox/hermes-profiles.nix`, replace this block:

```nix
  profileRoot = "/var/lib/hermes-profiles";
  profileCacheRoot = "/var/cache/hermes-profiles";
```

with:

```nix
  profileRoot = "/var/lib/hermes-profiles";
  profileCacheRoot = "/var/cache/hermes-profiles";
  dotfilesRoot = "/home/ryo-morimoto/ghq/github.com/ryo-morimoto/dotfiles";
  profileConfigRoot = "${dotfilesRoot}/config/hermes/profiles";
  profileConfigContainerPath = "/profile-config";
```

- [ ] **Step 2: Bump the container config version**

Replace:

```nix
  containerConfigVersion = 2;
```

with:

```nix
  containerConfigVersion = 3;
```

Expected: existing containers are recreated because the volume layout changes.

- [ ] **Step 3: Add profile config paths**

In `mkProfilePaths`, replace:

```nix
      workspaceDir = "${stateDir}/workspace";
      cacheDir = "${profileCacheRoot}/${profileName}";
      containerName = "hermes-${profileName}";
```

with:

```nix
      workspaceDir = "${stateDir}/workspace";
      cacheDir = "${profileCacheRoot}/${profileName}";
      profileConfigDir = "${profileConfigRoot}/${profileName}";
      containerName = "hermes-${profileName}";
```

- [ ] **Step 4: Create profile config directories in preStart**

In `mkContainerService.preStart`, after:

```sh
        install -d -m 0750 -o ${hermesUid} -g ${hermesGid} ${paths.cacheDir}
```

add:

```sh
        install -d -m 0755 -o ${hermesUid} -g ${hermesGid} ${paths.profileConfigDir}
        install -d -m 0755 -o ${hermesUid} -g ${hermesGid} ${paths.profileConfigDir}/skills
```

- [ ] **Step 5: Replace seed-only SOUL install with mutable config migration**

In `mkContainerService.preStart`, replace:

```sh
        if [ ! -e ${paths.workspaceDir}/SOUL.md ]; then
          install -m 0640 -o ${hermesUid} -g ${hermesGid} ${mkSoulSeed profileName profileConfig} ${paths.workspaceDir}/SOUL.md
        fi
```

with:

```sh
        if [ ! -e ${paths.profileConfigDir}/SOUL.md ]; then
          if [ -f ${paths.workspaceDir}/SOUL.md ] && [ ! -L ${paths.workspaceDir}/SOUL.md ]; then
            install -m 0640 -o ${hermesUid} -g ${hermesGid} ${paths.workspaceDir}/SOUL.md ${paths.profileConfigDir}/SOUL.md
          else
            install -m 0640 -o ${hermesUid} -g ${hermesGid} ${mkSoulSeed profileName profileConfig} ${paths.profileConfigDir}/SOUL.md
          fi
        fi

        if [ -e ${paths.workspaceDir}/SOUL.md ] && [ ! -L ${paths.workspaceDir}/SOUL.md ]; then
          if ! ${pkgs.diffutils}/bin/cmp -s ${paths.workspaceDir}/SOUL.md ${paths.profileConfigDir}/SOUL.md; then
            install -m 0640 -o ${hermesUid} -g ${hermesGid} ${paths.workspaceDir}/SOUL.md ${paths.workspaceDir}/SOUL.md.before-profile-config
          fi
          rm -f ${paths.workspaceDir}/SOUL.md
        fi
        ln -sfn ${profileConfigContainerPath}/SOUL.md ${paths.workspaceDir}/SOUL.md
```

Expected behavior:

- If config `SOUL.md` does not exist, existing runtime `SOUL.md` is copied into config.
- If both exist but differ, old runtime content is backed up before symlink replacement.
- Runtime `/workspace/SOUL.md` becomes a container-valid symlink to `/profile-config/SOUL.md`.

- [ ] **Step 6: Add skills migration and symlink**

In `mkContainerService.preStart`, after the `SOUL.md` symlink block, add:

```sh
        if [ -d ${paths.hermesHome}/skills ] && [ ! -L ${paths.hermesHome}/skills ]; then
          if [ -n "$(${pkgs.findutils}/bin/find ${paths.hermesHome}/skills -mindepth 1 -print -quit)" ]; then
            ${pkgs.coreutils}/bin/cp -a ${paths.hermesHome}/skills/. ${paths.profileConfigDir}/skills/
          fi
          rm -rf ${paths.hermesHome}/skills.before-profile-config
          mv ${paths.hermesHome}/skills ${paths.hermesHome}/skills.before-profile-config
        elif [ -e ${paths.hermesHome}/skills ] && [ ! -L ${paths.hermesHome}/skills ]; then
          rm -f ${paths.hermesHome}/skills
        fi
        ln -sfn ${profileConfigContainerPath}/skills ${paths.hermesHome}/skills
```

Expected behavior:

- Existing runtime skills are copied into dotfiles config before the directory is replaced.
- The old runtime skills directory is preserved as `skills.before-profile-config`.
- `$HERMES_HOME/skills` becomes a container-valid symlink to `/profile-config/skills`.

- [ ] **Step 7: Mount the profile config directory into the container**

In the `podman create` volume list, after:

```sh
            --volume ${paths.cacheDir}:/cache:rw \
```

add:

```sh
            --volume ${paths.profileConfigDir}:${profileConfigContainerPath}:rw \
```

- [ ] **Step 8: Include the config mount path in the identity hash**

In `mkIdentityHash`, inside the JSON attrset, add:

```nix
        profileConfigContainerPath = profileConfigContainerPath;
```

Expected: changes to the mount target path recreate containers. The host config file content itself does not recreate containers, which is intentional because the bind mount is live.

- [ ] **Step 9: Verify Nix formatting and parsing**

Run:

```bash
nixfmt --check hosts/ryobox/hermes-profiles.nix
nix-instantiate --parse hosts/ryobox/hermes-profiles.nix >/dev/null
git diff --check -- hosts/ryobox/hermes-profiles.nix
```

Expected: all commands exit with status `0`.

- [ ] **Step 10: Verify generated service contains bind mount and symlink migration**

Run:

```bash
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-container-dionysus".preStart' \
  | rg '/profile-config|before-profile-config|SOUL.md'

nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-container-dionysus".preStart' \
  | rg 'ln -sfn /profile-config/(SOUL.md|skills)'
```

Expected: output includes:

```text
ln -sfn /profile-config/SOUL.md /var/lib/hermes-profiles/dionysus/workspace/SOUL.md
ln -sfn /profile-config/skills /var/lib/hermes-profiles/dionysus/data/.hermes/skills
```

- [ ] **Step 11: Commit**

Run:

```bash
git add hosts/ryobox/hermes-profiles.nix
git commit -m "feat(hermes): mount mutable profile config"
```

Expected: pre-commit hooks pass and the commit succeeds.

---

### Task 3: Document the Config Ownership Model

**Files:**
- Modify: `docs/hermes-profiles-v0.1.md`

- [ ] **Step 1: Replace the current policy file note**

In `docs/hermes-profiles-v0.1.md`, replace:

```markdown
Nix seeds runtime `SOUL.md` only when a profile workspace does not already have one.
After bootstrap, `SOUL.md` and profile skills are Hermes-managed mutable state, not files
that Nix rewrites on every switch.
```

with:

```markdown
## Mutable Profile Config

`SOUL.md` and profile-local skills are Hermes-managed mutable config, stored in dotfiles:

```text
config/hermes/profiles/dionysus/SOUL.md
config/hermes/profiles/dionysus/skills/
config/hermes/profiles/apollon/SOUL.md
config/hermes/profiles/apollon/skills/
```

Each profile container receives only its matching config directory:

```text
config/hermes/profiles/<profile> -> /profile-config
/workspace/SOUL.md -> /profile-config/SOUL.md
$HERMES_HOME/skills -> /profile-config/skills
```

Nix manages the mount and symlink wiring, but it does not rewrite `SOUL.md` or skills after bootstrap.
Hermes may create and edit those files; review and commit intentional changes from `config/hermes/profiles/`.
```
```

- [ ] **Step 2: Add config verification commands to Checks**

In the `## Checks` command block, after:

```bash
sudo podman exec hermes-apollon printenv HERMES_PROFILE
```

add:

```bash
sudo podman exec hermes-dionysus readlink /workspace/SOUL.md
sudo podman exec hermes-apollon readlink /workspace/SOUL.md
sudo podman exec hermes-dionysus readlink /data/.hermes/skills
sudo podman exec hermes-apollon readlink /data/.hermes/skills
sudo podman exec hermes-dionysus test -w /profile-config/SOUL.md
sudo podman exec hermes-apollon test -w /profile-config/SOUL.md
```

Expected output for the `readlink` commands:

```text
/profile-config/SOUL.md
/profile-config/SOUL.md
/profile-config/skills
/profile-config/skills
```

- [ ] **Step 3: Verify docs mention mutable config and narrow mount**

Run:

```bash
rg -n 'Mutable Profile Config|/profile-config|Hermes-managed mutable config|review and commit' docs/hermes-profiles-v0.1.md
git diff --check -- docs/hermes-profiles-v0.1.md
```

Expected: `rg` prints all four markers and `git diff --check` exits with status `0`.

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/hermes-profiles-v0.1.md
git commit -m "docs(hermes): document mutable profile config"
```

Expected: commit succeeds.

---

### Task 4: Switch and Verify Runtime Wiring

**Files:**
- Runtime verification only.

- [ ] **Step 1: Build the system configuration**

Run:

```bash
nix build .#nixosConfigurations.ryobox.config.system.build.toplevel
```

Expected: build exits with status `0`.

- [ ] **Step 2: Switch the system configuration**

Run:

```bash
sudo nixos-rebuild switch --flake .
```

Expected: switch exits with status `0` and starts:

```text
hermes-container-dionysus.service
hermes-container-apollon.service
hermes-dashboard-dionysus.service
hermes-dashboard-apollon.service
hermes-gateway-dionysus.service
hermes-gateway-apollon.service
```

- [ ] **Step 3: Verify systemd state**

Run:

```bash
systemctl is-active \
  hermes-container-dionysus.service \
  hermes-container-apollon.service \
  hermes-dashboard-dionysus.service \
  hermes-dashboard-apollon.service
```

Expected:

```text
active
active
active
active
```

- [ ] **Step 4: Verify container symlinks**

Run:

```bash
sudo podman exec hermes-dionysus readlink /workspace/SOUL.md
sudo podman exec hermes-apollon readlink /workspace/SOUL.md
sudo podman exec hermes-dionysus readlink /data/.hermes/skills
sudo podman exec hermes-apollon readlink /data/.hermes/skills
```

Expected:

```text
/profile-config/SOUL.md
/profile-config/SOUL.md
/profile-config/skills
/profile-config/skills
```

- [ ] **Step 5: Verify per-profile config isolation**

Run:

```bash
sudo podman exec hermes-dionysus sh -lc 'test -f /profile-config/SOUL.md && rg -n "Dionysus|personal/hobby|Use personal/hobby services only" /profile-config/SOUL.md'
sudo podman exec hermes-apollon sh -lc 'test -f /profile-config/SOUL.md && rg -n "Apollon|work operations|Use work services only" /profile-config/SOUL.md'
```

Expected:

- Dionysus command prints only Dionysus/personal markers.
- Apollon command prints only Apollon/work markers.

- [ ] **Step 6: Verify Hermes can write profile config**

Run:

```bash
sudo podman exec hermes-dionysus sh -lc 'echo dionysus-write-test > /profile-config/skills/.write-test && rm /profile-config/skills/.write-test'
sudo podman exec hermes-apollon sh -lc 'echo apollon-write-test > /profile-config/skills/.write-test && rm /profile-config/skills/.write-test'
```

Expected: both commands exit with status `0`.

- [ ] **Step 7: Verify dashboards still answer locally**

Run:

```bash
curl -I http://127.0.0.1:9120/
curl -I http://127.0.0.1:9130/
```

Expected: both commands return an HTTP response header. `200`, `302`, or another Hermes dashboard response is acceptable; connection refused or timeout is not.

- [ ] **Step 8: Commit any switch-time config migrations**

Run:

```bash
git status --short config/hermes/profiles
```

Expected:

- If Nix migrated runtime skills or updated profile config files, inspect the diff.
- Commit intentional config changes:

```bash
git add config/hermes/profiles
git commit -m "chore(hermes): capture migrated profile config"
```

- If there are no changes, do not create an empty commit.

---

## Self-Review

**Spec coverage:** The plan covers mutable `SOUL.md`, mutable skills, narrow per-profile mounting, container-visible symlink targets, existing runtime migration, docs, and runtime verification.

**Placeholder scan:** No `TBD`, `TODO`, "similar to", or unspecified code steps remain.

**Type consistency:** The plan consistently uses `dionysus`, `apollon`, `/profile-config`, `profileConfigDir`, `profileConfigRoot`, and `profileConfigContainerPath`.

