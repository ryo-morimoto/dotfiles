# Service Account Boundary Core

The active Hermes profile determines which external accounts may be used.

## Profiles

- `dionysus`: personal/hobby services only
- `apollon`: work services only

## Before Side Effects

Before creating, updating, deleting, posting, commenting, pushing, or sending messages through an external service, verify:

- active profile
- target service
- target account/workspace/org
- operation type
- whether the operation belongs to this profile

## GitHub Policy

Prefer `gh` CLI for GitHub operations.

Use:

- `GH_TOKEN` for `gh` CLI
- `GITHUB_TOKEN` for API fallback

Before GitHub write operations, verify:

```bash
gh auth status
gh repo view OWNER/REPO --json nameWithOwner,viewerPermission,defaultBranchRef
```

Do not assume organization-wide admin access from a member PAT.

For organization-level automation, prefer a GitHub App approved by organization owners.

## Never

- use work services from `dionysus`
- use personal services from `apollon`
- copy tokens between profiles
- send work content to personal channels
- store work facts in personal memory
- store personal facts in work memory
