# Policy DSL

## Design overview

`policy.toml` is the user-facing policy surface. It is a TOML file
discovered at `<base-repo-root>/.sandbox/policy.toml` and resolved
through an `extends` chain into a single in-memory `Policy` struct. The
DSL design balances three forces:

- **Readable for humans** — TOML, named keys, no Starlark or JSONC
  comment editing dance.
- **Validatable at parse time** — every `[[commands]]` rule must declare
  positive `examples` and negative `not_examples`; rule loading fails
  loudly if an example doesn't match its own pattern.
- **Compositional** — `extends` lets a project policy stand on top of a
  built-in template (`@builtin/code`, `@builtin/git-readonly`) with
  deterministic merge semantics.

Key decisions:

- **TOML over Starlark**. Codex uses Starlark in `execpolicy`; we use
  TOML. Reason: agents need to read and write the policy, and TOML is
  what the rest of the broker is configured in (ditto Nix consuming it).
- **Asymmetric category defaults**, hard-coded into the schema. Users
  cannot redefine `filesystem.read.default` semantics — only what's
  in/out of the deny list. This keeps "allow-list" and "deny-list"
  worlds from colliding within one category.
- **Mandatory-deny is bedrock + user_extra**. Users add to the list,
  never remove from it. The bedrock is `include_str!`-loaded at compile
  time.
- **Examples are required for `[[commands]]`**, validated at parse time.
  An unmatchable rule fails loudly.

## Top-level schema

```toml
extends = ["@builtin/code"]            # zero or more, resolved left-to-right then self merged on top

[mandatory_deny.write]
user_extra = []                         # paths user adds to the bedrock list

[filesystem.read]
default = "allow"                       # only "allow" is valid; this is documentation
deny = [".env", ".env.*", "**/secrets/**", "~/.ssh/**", "~/.aws/**", "~/.netrc"]
allow = []                              # explicit allows (rare; mostly for negating template denies)

[filesystem.write]
default = "deny"                        # only "deny" is valid; this is documentation
allow = ["./**", "/tmp/**"]
deny = ["./.env*"]                      # carve-outs within an allowed root

[network]
allow_loopback = true
allow_domains = ["api.anthropic.com", "github.com", "*.npmjs.org"]
deny_domains = ["169.254.169.254", "metadata.google.internal"]

[[commands]]
pattern = ["git", ["status", "diff", "log", "show", "branch"]]
decision = "allow"
examples = [["git", "status"], ["git", "log", "--oneline"]]
not_examples = [["git", "push"]]
justification = "local read-only inspection"

[[commands]]
pattern = ["git", "push", "*"]
decision = "ask"
examples = [["git", "push", "origin", "main"]]
justification = "publishing requires confirmation"

[runtime]
daemonize = true
fail_open_on_hook_error = true          # hook subprocess errors → allow (Codex-style)
wrap_allowed_bash = false               # Phase 2: rewrite to `landrun -- bash -c …`

[worktree]
allow_siblings = true                    # programmatic_check allows reads of *-wt/ siblings
```

## `extends` inheritance

`extends` accepts:

- **Built-in templates**: `@builtin/code`, `@builtin/code-strict`,
  `@builtin/git-readonly` (Phase 1).
- **Other paths** (Phase 2): relative paths to `.toml` files, e.g.
  `extends = ["./common.toml"]`. Discovered relative to the file
  containing the `extends`. Cycles are detected and produce a parse
  error.
- **`@base`** (Phase 2): re-uses the user-default policy at
  `~/.config/sandbox-broker/global.toml` as a parent. Borrowed from
  [Fence](./refs/fence.md).

Multiple `extends` resolve **left-to-right**, then the current file
overlays. So `extends = ["@builtin/code", "./team-overrides.toml"]`
means: start from `code`, layer team overrides, then layer this file.

### Merge semantics

Borrowed wholesale from [Fence's `Merge`](./refs/fence.md#policy--config-dsl):

- **Slices append-then-dedupe** — `filesystem.read.deny` from parent and
  child are concatenated, then deduplicated by string equality.
- **Booleans OR** — `network.allow_loopback` is `parent || child`. This
  means a child can switch on a permissive bool but can't switch off a
  parent's `true`. (This direction is intentional: parents are usually
  templates that grant capabilities; children should not silently revoke.)
- **Scalars override** — `runtime.daemonize`, `runtime.fail_open_on_hook_error`
  use the most-specific declaration.
- **`[[commands]]` array-of-tables append** by parent-then-child order.
  Within a stage 2 match, the broker iterates rules in array order; the
  first match wins. So child rules can shadow parent rules by appearing
  earlier-or-later, depending on whether you want to override or add.

The merge is implemented in `policy::merge` and is unit-tested with
synthetic parent/child cases — see [testing.md](./testing.md#policy-merge).

## `mandatory_deny` shape

```toml
[mandatory_deny.write]
user_extra = ["**/.aws/credentials"]
```

Bedrock list (build-time hard-coded in `mandatory_deny::BEDROCK`):

- `**/.bashrc`, `**/.zshrc`, `**/.profile`, `**/.bash_profile`
- `**/.gitconfig`, `**/.git-credentials`
- `**/.git/hooks/**`
- `**/.mcp.json`
- `**/.claude/commands/**`, `**/.claude/skills/**`,
  `**/.claude/settings.json`, `**/.claude/settings.local.json`
- `**/.codex/**`
- `**/.cursor/**`
- `**/.sandbox/policy.toml`, `**/.sandbox/global.toml`

The bedrock is **not** in `policy.toml`. It cannot be removed. Users add
extras via `mandatory_deny.write.user_extra`.

`mandatory_deny.read` is intentionally not supported — agents need to
read their own config. If a path needs read protection, use
`filesystem.read.deny` (which the agent's policy can override per
template, unlike mandatory_deny).

## `[filesystem]`

### `read`

```toml
[filesystem.read]
default = "allow"
deny = [".env", ".env.*", "**/secrets/**", "~/.ssh/**", "~/.aws/**"]
allow = []                               # only used to negate template denies
```

Semantics:

- `default = "allow"` is a **literal documentation field** that must be
  present and must be `"allow"`. The schema rejects other values. We
  use it as a self-checking comment: anyone reading the config knows
  the convention.
- `deny` patterns: glob patterns matched against the operation's path.
  Tilde `~` expands at parse time to `$HOME`. Patterns are anchored to
  whole paths.
- `allow` patterns: rare; used to override an inherited `deny`. E.g.
  the team template denies `~/.aws/**` but a specific project allows
  `~/.aws/config`. Order: `allow` wins over `deny` only when both
  match; otherwise `deny` wins over default.

Stage-3 verdict for read:

| Case | Verdict |
|---|---|
| In `allow` (literal allow) | Allow |
| In `deny` and not in `allow` | Deny |
| Neither | Allow (`default = "allow"`) — does not fall through to escalate |

### `write`

```toml
[filesystem.write]
default = "deny"
allow = ["./**", "/tmp/**"]
deny = ["./.env*"]                       # carve-outs
```

Semantics:

- `default = "deny"` is the documentation field; only `"deny"` is valid.
- `allow` patterns: glob patterns of paths the agent may write.
- `deny` patterns: carve-outs *within* an `allow` root. `./.env*` is
  denied even though `./**` is allowed.

Stage-3 verdict for write:

| Case | Verdict |
|---|---|
| In `deny` | Deny (regardless of `allow`) |
| In `allow` and not in `deny` | Allow |
| Neither | NoMatch → continues to stage 4–7 → escalate |

The `default = "deny"` is enforced at stage 7 fall-through, not stage 3,
so a write-not-covered passes through to programmatic checks (which may
flag hidden-file writes specifically).

## `[network]`

```toml
[network]
allow_loopback = true
allow_domains = ["api.anthropic.com", "github.com", "*.npmjs.org"]
deny_domains = ["169.254.169.254", "metadata.google.internal"]
```

Domain pattern syntax:

- `host.example.com` — exact match
- `*.example.com` — one-or-more-level subdomain match (`api.example.com`
  matches; `example.com` does not)
- IP literals (`169.254.169.254`, `::1`) — match exactly as IPs (no
  wildcard for IPs)

**Hardening** (borrowed from sandbox-runtime's
`matchesDomainPattern`):

- Bare `*` is rejected at parse time
- `*.com`, `*.org`, top-level wildcards are rejected
- Schemes (`http://`, `https://`) and paths in patterns are rejected
- Hosts are canonicalised before match — `inet_aton` shorthand
  (`2852039166`) is decoded to `127.0.0.1` and matched as IP

Stage-4 verdict:

| Case | Verdict |
|---|---|
| Loopback host (`127.0.0.1`, `::1`, `localhost`) and `allow_loopback = true` | Allow |
| In `deny_domains` | Deny |
| In `allow_domains` | Allow |
| Neither | NoMatch → escalate at stage 7 |

`allow_loopback` is on in `@builtin/code` because dev servers are the
canonical thing the agent needs to connect to (`localhost:3000`,
`localhost:8080`, etc.). Strict templates can flip it off and add
explicit `:loopback:3000` allow rules — Phase 2 syntax.

## `[[commands]]` prefix-rules

```toml
[[commands]]
pattern = ["git", ["status", "diff", "log", "show", "branch"]]
decision = "allow"
examples = [["git", "status"], ["git", "log", "--oneline"]]
not_examples = [["git", "push"]]
justification = "local read-only inspection"
```

Semantics in [matcher.md](./matcher.md#prefix-rule). Fields:

| Field | Required | Description |
|---|---|---|
| `pattern` | Yes | List of tokens. First is fixed string. Subsequent items are either a string (exact match) or a list of strings (alternatives). The pattern matches if the operation's argv starts with this many tokens, each matching the corresponding pattern element. |
| `decision` | Yes | `"allow"` / `"deny"` / `"ask"` |
| `examples` | Yes | Array of argvs that *must* match the pattern. At least one example required. Validated at parse time. |
| `not_examples` | No | Array of argvs that *must not* match the pattern. Validated at parse time. |
| `justification` | No | Human-readable reason; surfaced in the verdict's `rationale`. |

Borrowed from [Codex's `prefix_rule`](./refs/codex.md#approval-policy-dsl).
Unlike Codex's Starlark, our parse-time validation is at TOML load time
in Rust; failures abort `start`.

### Validation rules

For each `[[commands]]` rule:

- `examples` must be non-empty. A rule with no positive example is a
  parse error (you accidentally wrote a rule that does nothing useful).
- Every entry in `examples` must match the rule's `pattern`. If not,
  parse error: "rule's pattern does not match its own example".
- Every entry in `not_examples` must NOT match the rule's pattern. If
  any does, parse error: "rule's pattern matches its negative example".

This catches the common mistake of `pattern = ["git", "push", "*"]`
with `examples = [["git", "push"]]` (the `*` requires a third token).

## `[runtime]` knobs

```toml
[runtime]
daemonize = true                         # default: true
fail_open_on_hook_error = true           # default: true (Codex-style)
wrap_allowed_bash = false                # default: false (Phase 2 feature)
require_landlock = false                 # default: false; if true, doctor must show Landlock available
require_bwrap = false                    # default: false
hook_timeout_ms = 2000                   # default: 2000
```

| Knob | Effect |
|---|---|
| `daemonize` | `start` (no flag) forks via self-reexec into `--foreground` and exits. `start --foreground` overrides to stay in foreground. |
| `fail_open_on_hook_error` | When the hook subcommand fails to reach the broker (timeout, broken pipe, malformed reply), `true` returns `permissionDecision: allow`; `false` returns `deny`. The default is open-on-error to avoid bricking sessions. |
| `wrap_allowed_bash` (Phase 2) | When true, allowed Bash is rewritten to `landrun --rw=$cwd --connect-tcp=… -- bash -c <orig>` for kernel-enforced confinement. |
| `require_landlock`, `require_bwrap` | Enforce capability availability at start. The boot probe (`lifecycle::capability::probe`) records what's available; an enabled `require_*` plus an unavailable primitive aborts `start` with a clear error message. |
| `hook_timeout_ms` | Hook subcommand's curl timeout when calling the broker. |

## `[worktree]`

```toml
[worktree]
allow_siblings = true
```

When `true`, `programmatic_check` (stage 6) allows reads of paths
matching `**-wt/**` (the convention for git worktree siblings) so a
multi-worktree project doesn't need policy edits. Default `true` in
all built-in templates.

## Built-in templates

See [templates.md](./templates.md) for the full content of each. Phase 1
ships `@builtin/code`, `@builtin/code-strict`, `@builtin/git-readonly`.

Templates are stored as `.toml` strings in
`policy::templates::BUILTINS: phf::Map<&str, &str>` (a `phf` perfect
hash map for compile-time lookup). The `@builtin/` prefix in `extends`
strips and looks up.

---

## Key design decisions

- **TOML, not Starlark or JSONC**. Parse-time validation can be done in
  Rust against `serde::Deserialize` schemas; users can edit policies in
  any TOML editor; Nix can produce policies declaratively.

- **`extends` resolves at policy load time, not at evaluator time**. The
  evaluator sees a single resolved `Policy` struct; merge has happened.
  Makes `policy show` straightforward and the evaluator stateless wrt
  inheritance.

- **`default` fields are documentation, not knobs**. `filesystem.read.default
  = "allow"` is required and must be the literal `"allow"`. Anyone
  reading the config sees the convention; anyone trying to flip the
  default gets a parse error pointing them to use `allow` / `deny` lists
  instead.

- **Examples are required for `[[commands]]`**. Codex's
  [`prefix_rule`](./refs/codex.md#approval-policy-dsl) accepts examples
  as optional and validates at parse time; we make them mandatory. A
  rule whose author can't think of an example to which it applies isn't
  a useful rule.

- **Mandatory-deny is build-time, not runtime**. The bedrock list lives
  in Rust source and is compiled in. Users cannot remove items from it.
  This is the only way to give a believable "the agent cannot rewrite
  its own permissions" guarantee — anything in the policy file is
  potentially an attack surface.
