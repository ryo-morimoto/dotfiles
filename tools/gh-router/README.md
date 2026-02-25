# gh-router

`gh-router` resolves a GitHub account from repository context and applies the matching `GH_CONFIG_DIR`.

This tool is designed to stay independent from Nix packages so it can be extracted into a standalone repository later.

## Resolution Algorithm

1. **owner-profile**: Owner matches an account name directly
2. **org-membership**: Owner is an org that an account belongs to (via `/user/orgs`, cached per account)
3. **fallback-default**: Falls back to `GH_ROUTER_DEFAULT_ACCOUNT`

## Commands

- `gh-router apply --shell zsh [--cwd PATH]`
- `gh-router status [--cwd PATH] [--verbose]`
- `gh-router resolve [--cwd PATH] [--verbose]`
- `gh-router login <account> [gh auth login options...]`
- `gh-router clear-cache`
- `gh-router sync-identity [--cwd PATH]`
- `gh-router credential [get|store|erase]`
- `gh-router doctor`

## Configuration

- `GH_ROUTER_PROFILE_ROOT` (default: `~/.local/state/gh-router/profiles`)
- `GH_ROUTER_DEFAULT_ACCOUNT`
- `GH_ROUTER_ORG_CACHE_TTL` (default: `86400` / 24h)

## Notes

- Runtime behavior is stateless (no active-account session state).
- Org lists are fetched via `/user/orgs` per account and cached with TTL.
- Identity (name/email) is cached per account to avoid API calls on every `cd`.
- Profiles are auto-hydrated from `gh auth status --json hosts` when possible.
- `gh-router login` is optional when accounts already exist in global gh auth state.
- `sync-identity` updates `git config --local user.name/user.email` for resolvable GitHub repos.
- `gh-router doctor` validates token isolation, file permissions, and credential helper setup.
- Profile directories use 700 permissions; hosts.yml uses 600.
