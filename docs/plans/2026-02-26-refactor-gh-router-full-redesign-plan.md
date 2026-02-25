---
title: "refactor: Full redesign of gh-router"
type: refactor
date: 2026-02-26
---

# refactor: Full redesign of gh-router

## Overview

gh-router is a ~832-line bash script that transparently routes GitHub CLI (`gh`) commands and git credentials to the correct GitHub account based on repository context. This redesign replaces the current resolution chain with account-based org resolution, removes the owner-map override mechanism, hardens security, adds debuggability, and prepares the architecture for future extraction to a standalone repository.

## Problem Statement / Motivation

1. **Token isolation was broken**: Both accounts shared the same OS keyring token. Re-login fixed this, but the tool had no way to detect or warn about the issue.
2. **owner-map was a workaround**: The `owner-map.tsv` existed because org resolution didn't work (tokens were identical). With proper token isolation, account-based org resolution is now viable.
3. **No debuggability**: When routing fails, there is no verbose/debug mode. The session that discovered the token issue required extensive manual `gh api` calls.
4. **Security gaps**: Profile directories and `hosts.yml` files are created with default umask (potentially 644), leaking account structure.
5. **Org probe is inefficient**: Current code calls `/user/memberships/orgs/{owner}` per-owner-per-account (up to 2 API calls each). Switching to `/user/orgs` (list-all) enables one call per account cached for all lookups.
6. **sync-identity latency**: Every `cd` into a repo triggers `gh api /user`, adding 100-500ms shell latency.
7. **No self-diagnosis**: No `doctor` command to validate token isolation, permissions, or cache state.

## Proposed Solution

### New Resolution Algorithm

Priority order (simplified from current 6-step chain):

```
Step 1: owner == account name?       -> that account (reason: owner-profile)
Step 2: owner in org-list cache?     -> cached account (reason: org-cache)
Step 3: for each account, /user/orgs -> first match (reason: org-membership)
Step 4: fallback DEFAULT_ACCOUNT     -> ryo-morimoto (reason: fallback-default)
```

Key changes:
- **owner-map removed** (Step 1 of old chain eliminated)
- **API endpoint changed**: `/user/memberships/orgs/{owner}` -> `/user/orgs` (list-all, cache per-account)
- **Org cache restructured**: Store full org-list per account (not per-owner mapping)

### File Structure (redesign target)

```
tools/gh-router/
  gh-router              # Main script (target: <600 lines)
  test/                  # Shell test suite (new)
    test-resolve.sh
    test-credential.sh
    test-cache.sh
  README.md              # Updated documentation
```

### Subcommands (retained/changed/new)

| Command | Status | Change |
|---|---|---|
| `resolve --cwd PATH` | retained | New algorithm, add `--verbose` |
| `apply --shell zsh --cwd PATH` | retained | No change |
| `status --cwd PATH` | retained | Add `--verbose` for resolution trace |
| `login ACCOUNT` | retained | Add permission hardening, validate token isolation |
| `credential get/store/erase` | retained | Remove owner-map references |
| `sync-identity --cwd PATH` | retained | Cache identity per account (no API call per cd) |
| `clear-cache` | retained | Clear new org-list cache format |
| `list-accounts` | retained | No change |
| `doctor` | **new** | Validate tokens, permissions, org resolution |

### Removed Features

- `owner-map.tsv` file support
- `GH_ROUTER_OWNER_MAP` environment variable
- `owner_map_get_*` functions (~50 lines)
- Resolution step: owner-map lookup

## Technical Considerations

### API Strategy: `/user/orgs` vs `/user/memberships/orgs/{owner}`

**Decision: `/user/orgs`**

- One API call per account, returns full org list
- Cache the entire list per account with TTL (positive: 24h, no negative cache needed)
- Local lookup: `owner in cached_org_list[account]?`
- Rate limit impact: 2 API calls total (one per account) on cold cache, vs 2*N calls for N unknown owners under old strategy

### Identity Cache

**Decision: Cache `gh api /user` response per account**

- Store `name`, `login`, `email` in `$CACHE_ROOT/identity/{account}.tsv`
- TTL: 24h (same as org cache)
- `sync-identity` reads from cache, no API call on `chpwd`
- `login` command invalidates identity cache for that account

### Permission Hardening

```bash
ensure_dirs() {
  mkdir -p -m 700 "$PROFILE_ROOT" "$CACHE_ROOT" "$CONFIG_ROOT"
}

ensure_profile_for_account() {
  # ... existing logic ...
  chmod 600 "$profile_dir/hosts.yml"
}
```

### `doctor` Command

Validates:
1. Each profile has a working token (`gh api /user --jq .login` returns expected account)
2. Tokens are isolated (different token per profile)
3. Directory permissions are 700, hosts.yml is 600
4. Org resolution matches expected behavior for known repos
5. Credential helper is registered in git config

Output format:
```
[OK]   profile ryo-morimoto: token valid, login=ryo-morimoto
[OK]   profile morimoto-novasto: token valid, login=morimoto-novasto
[OK]   tokens isolated (different per profile)
[OK]   permissions: profiles/ 700, hosts.yml 600
[WARN] credential helper not registered in git config
```

### `--verbose` Flag

When `--verbose` is passed to `resolve` or `status`:

```
[resolve] cwd=/home/.../commercex-holdings/yuhaku-app
[resolve] owner=commercex-holdings (source: ghq-path)
[resolve] step 1: owner-profile match? no (commercex-holdings != ryo-morimoto, morimoto-novasto)
[resolve] step 2: org-cache hit? no (cache miss for commercex-holdings)
[resolve] step 3: probe ryo-morimoto orgs=[sushi-days,moritech-dev] -> no match
[resolve] step 3: probe morimoto-novasto orgs=[novasto,commercex-holdings] -> MATCH
[resolve] result: account=morimoto-novasto reason=org-membership
```

### Shell Integration Changes

`config/zsh/custom.zsh` changes:
- No functional changes to `gh()` wrapper or `chpwd` hook
- `sync-identity` will be faster (cached identity, no API call)
- Remove any `gh-router-*` aliases that reference owner-map

### Migration

One-time steps after applying the redesign:
1. `gh-router clear-cache` (old cache format incompatible)
2. `gh-router doctor` (verify token isolation is correct)
3. Delete `~/.config/gh-router/owner-map.tsv` if it exists

## Acceptance Criteria

- [x] `gh-router resolve --cwd ~/ghq/github.com/commercex-holdings/yuhaku-app` returns `account=morimoto-novasto`
- [x] `gh-router resolve --cwd ~/ghq/github.com/ryo-morimoto/dotfiles` returns `account=ryo-morimoto`
- [x] `gh-router resolve --cwd ~/ghq/github.com/smcllns/Claude-Code-TMUX-Status-Bar` returns `account=ryo-morimoto` (default fallback)
- [x] `gh` commands use the resolved account's `GH_CONFIG_DIR`
- [x] `git push` routes credentials through the correct account via credential helper
- [x] `gh-router doctor` passes all checks on a correctly configured system
- [x] `gh-router resolve --verbose` shows full resolution trace
- [x] Profile directories are 700, hosts.yml files are 600
- [x] No `owner-map` references remain in code or documentation
- [x] `sync-identity` does not make API calls on every `chpwd` (uses cache)
- [x] `gh-router login <account>` re-validates token isolation and invalidates caches
- [x] Cold-cache org resolution requires at most 2 API calls (one `/user/orgs` per account)

## Success Metrics

- `gh-router resolve` completes in <50ms on cache hit (no API calls)
- `cd` into a repo with `sync-identity` does not add perceptible latency (cached identity)
- `gh-router doctor` catches the token-sharing issue that took a full debugging session to find
- Zero `owner-map` references in codebase

## Dependencies & Risks

**Dependencies:**
- OS keyring tokens must be correctly isolated per account (confirmed working after re-login)
- `gh auth status --json hosts` must list all accounts (used for profile hydration)
- `gh api /user/orgs` must return org memberships (confirmed: `read:org` scope present on both tokens)

**Risks:**
- **Keyring token re-contamination**: If user runs `gh auth login` against global config without `gh-router login`, tokens could become shared again. Mitigation: `doctor` command detects this.
- **Private org visibility**: Some orgs may not appear in `/user/orgs` depending on org settings. Mitigation: fallback to default account (acceptable per user decision).
- **Cache staleness**: If user is added to a new org, gh-router won't detect it until cache expires (24h) or `clear-cache` is run. Mitigation: document this, `login` command clears cache.

## References & Research

### Internal References

- Main script: `tools/gh-router/gh-router` (832 lines, all resolution logic)
- Shell integration: `config/zsh/custom.zsh:13-91` (wrappers, chpwd hook)
- Git credential config: `home/default.nix:207-209` (credential helper registration)
- README: `tools/gh-router/README.md`

### Key Commits

- `0b17dfa` - move gh-router into tools and sync git identity
- `130fc6f` - add gh credential helper
- `f0474f0` - simplify git/gh config using credential helper

### Session Discoveries

- Token isolation was broken: both keyring entries returned same token (`gho_hXBB...`)
- After `gh auth login --hostname github.com --web` for morimoto-novasto, tokens are now isolated
- `morimoto-novasto` orgs: `novasto,commercex-holdings`
- `ryo-morimoto` orgs: `sushi-days,moritech-dev`
- `insecure-storage` explicitly rejected by user (security concern)

### Spec-Flow Analysis Gaps Addressed

| Gap | Resolution |
|---|---|
| GAP 3.1: API endpoint choice | `/user/orgs` (list-all, cache locally) |
| GAP 3.4: owner-map contradiction | Removed entirely |
| GAP 3.5: File permissions | Hardened to 700/600 |
| GAP 3.6: Token storage strategy | Keyring-only, doctor validates |
| GAP 3.14: Silent failure masking | `--verbose` flag added |
| GAP 3.15: No debug mode | `--verbose` on resolve/status |
| GAP 3.17: Migration path | Documented (clear-cache, doctor, delete owner-map) |

### Deferred (out of scope)

- GitHub Enterprise Server support (GAP 3.18)
- Bash/fish shell support (GAP 3.10)
- Cache file locking (GAP 3.11, low risk)
- Fork-upstream credential mismatch (GAP 3.21)
