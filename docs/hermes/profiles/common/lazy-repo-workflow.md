# Lazy Repo Workflow

Projects are remote repositories discovered through the active profile's GitHub account.

## Discovery

Use:

```bash
gh repo view OWNER/REPO --json nameWithOwner,sshUrl,defaultBranchRef,viewerPermission
```

or:

```bash
gh repo list OWNER --limit 100 --json nameWithOwner,sshUrl,visibility,isPrivate
```

## Clone

Clone only when needed:

```bash
mkdir -p /workspace/repos/OWNER
gh repo clone OWNER/REPO /workspace/repos/OWNER/REPO
```

## Existing Checkout

If the repo already exists:

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
