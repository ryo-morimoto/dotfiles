# gh-router

`gh-router` resolves a GitHub account from repository context and applies the matching `GH_CONFIG_DIR`.

This tool is designed to stay independent from Nix packages so it can be extracted into a standalone repository later.

## Commands

- `gh-router apply --shell zsh [--cwd PATH]`
- `gh-router status [--cwd PATH]`
- `gh-router resolve [--cwd PATH]`
- `gh-router login <account> [gh auth login options...]`
- `gh-router clear-cache`
- `gh-router sync-identity [--cwd PATH]`
- `gh-router credential [get|store|erase]`

## Configuration

- `GH_ROUTER_PROFILE_ROOT` (default: `~/.local/state/gh-router/profiles`)
- `GH_ROUTER_OWNER_MAP` (`owner=account,owner2=account2`)
- `GH_ROUTER_OWNER_MAP_FILE` (default: `~/.config/gh-router/owner-map.tsv`)
- `GH_ROUTER_DEFAULT_ACCOUNT`
- `GH_ROUTER_ORG_CACHE_TTL_POSITIVE`
- `GH_ROUTER_ORG_CACHE_TTL_NEGATIVE`

## Notes

- Runtime behavior is stateless (no active-account session state).
- Organization membership is cached with TTL.
- Negative cache is only written for definitive 404-style misses.
- Profiles are auto-hydrated from `gh auth status --json hosts` when possible.
- `gh-router login` is optional when accounts already exist in global gh auth state.
- `sync-identity` updates `git config --local user.name/user.email` for resolvable GitHub repos.
