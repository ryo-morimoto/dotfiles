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

## Policy Files

Profile policy lives in this repo for review and evolution:

```text
docs/hermes/profiles/common/agentic-development-core.md
docs/hermes/profiles/common/service-account-boundary-core.md
docs/hermes/profiles/common/lazy-repo-workflow.md
docs/hermes/profiles/common/operation-safety.md
docs/hermes/profiles/dionysus/dionysus-personality-policy.md
docs/hermes/profiles/apollon/apollon-personality-policy.md
skillset.yaml
```

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

## Lazy Repo Workflow

Open a development shell:

```bash
sudo podman exec -it --workdir /workspace hermes-dionysus /tools/bin/bash
sudo podman exec -it --workdir /workspace hermes-apollon /tools/bin/bash
```

Each container sets:

```text
HOME=/data/home
XDG_CONFIG_HOME=/data/home/.config
XDG_DATA_HOME=/data/home/.local/share
XDG_CACHE_HOME=/cache/xdg
PATH=/tools/bin:...
```

GitHub CLI auth is profile-local:

```bash
gh auth login
gh auth status
```

`gh` stores auth under the active container's `/data/home/.config/gh`, so `dionysus` and `apollon` do not share GitHub auth state.

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
sudo podman exec hermes-dionysus readlink /workspace/SOUL.md
sudo podman exec hermes-apollon readlink /workspace/SOUL.md
sudo podman exec hermes-dionysus readlink /data/.hermes/skills
sudo podman exec hermes-apollon readlink /data/.hermes/skills
sudo podman exec hermes-dionysus test -w /profile-config/SOUL.md
sudo podman exec hermes-apollon test -w /profile-config/SOUL.md

curl -I http://127.0.0.1:9120/
curl -I http://127.0.0.1:9130/

ss -ltnp | rg '127\.0\.0\.1:(9120|9130)'
ss -ltnp | rg '0\.0\.0\.0:(9120|9130)'
```

The `readlink` checks should print:

```text
/profile-config/SOUL.md
/profile-config/SOUL.md
/profile-config/skills
/profile-config/skills
```
