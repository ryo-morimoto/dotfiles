# Testing strategy

## Design overview

The broker's correctness has three orthogonal axes:

1. **Policy parsing and validation** — does invalid TOML fail loudly?
   Do `extends` chains resolve deterministically? Do bad examples
   reject?
2. **Verdict correctness** — for each (policy, operation) pair, does
   the seven-stage chain produce the expected `Verdict`?
3. **Lifecycle / IO correctness** — does the daemon start, accept
   connections, drain on signal, write the audit log? Do the hook
   subcommands speak the agent wire shapes correctly?

We address each axis with targeted tests; they are deliberately
non-overlapping so a failure points at exactly one layer.

Key decisions:

- **White-box unit tests** for policy / matcher / evaluator. Library
  crate exposes the modules; tests import them directly.
- **Black-box integration tests** for hook subcommands. Tests spawn
  `sandbox-broker hook claude/codex` as a subprocess, pipe JSON, parse
  stdout. Mirrors how Claude Code / Codex actually call us.
- **End-to-end test** for the full daemon path: spawn broker, hit
  `/evaluate`, verify response. Catches the wire-protocol regressions
  unit tests miss.
- **Test corpus reused** from existing `tests/` where applicable.
  Existing fixtures (`hook_test.rs::fixture()`) translate to the new
  hook subcommand entry points with minimal change.

## Test categories

The Phase 1 test plan defines 10 categories. Each lives in its own
`tests/<category>_test.rs` file.

### 1. Policy parse

`tests/policy_parse_test.rs`:

- Valid `policy.toml` round-trips (parse → serialize → parse equals
  original)
- Each built-in template parses without error
- Missing required fields produce specific, line-numbered errors
- Schema mismatches (`filesystem.read.default = "deny"`) produce a
  pointed error
- Tilde expansion happens at parse time
- Brace expansion in path patterns produces multiple stored patterns
- Domain patterns: bare `*` rejected, `*.com` rejected, scheme rejected,
  IPv6 brackets accepted

### 2. `extends` and merge

`tests/policy_merge_test.rs`:

- `extends = ["@builtin/code"]` resolves correctly
- Two-level extends chain (`extends` in the parent points to another
  parent)
- Cycle detection: `A extends B extends A` rejected
- Slice append-dedupe: parent and child each have `deny` list, merged
  result preserves order and removes duplicates
- Bool OR: `network.allow_loopback = true` in parent, child silent →
  result `true`. Parent `false`, child `true` → `true`. Parent `true`,
  child `false` → `true` (intentional: child can't silently revoke).
- Scalar override: `runtime.daemonize` parent `true`, child `false` →
  child wins
- `[[commands]]` array append in parent-then-child order

### 3. Matcher (prefix-rule)

`tests/matcher_prefix_test.rs`:

- Exact match: `pattern = ["git", "status"]` matches `["git", "status"]`
- With trailing extras: matches `["git", "status", "--short"]`
- Doesn't match shorter argv
- Doesn't match different first token
- Alternatives: `pattern = ["git", ["status", "log"]]` matches
  `["git", "status"]` and `["git", "log"]`, doesn't match `["git",
  "push"]`
- First-token alternatives: `pattern = [["npm", "pnpm"], "install"]`
  matches both
- `examples` validation: a rule with example that doesn't match its
  pattern fails parse
- `not_examples` validation: a rule with not_example that does match
  fails parse
- O(1) prefiltering by first token: large rule set lookup is fast

### 4. Matcher (path-glob)

`tests/matcher_path_test.rs`:

- `*` doesn't cross `/`
- `**` matches multiple segments
- Tilde expansion at parse: `~/.ssh/**` becomes `/home/user/.ssh/**`
  before storage
- Brace expansion: `{a,b}.txt` produces two patterns, each matches
  appropriately
- `./**` matches workspace-relative paths
- Symlink within tree: resolved
- Symlink leaving tree: not resolved (matched as the symlink path)
- `/tmp/**` matches absolute paths

### 5. Matcher (domain pattern)

`tests/matcher_domain_test.rs`:

- Exact: `github.com` matches `github.com` only
- Subdomain wildcard: `*.github.com` matches `api.github.com`,
  `raw.github.com`, `a.b.github.com`; doesn't match `github.com` itself
- IP literal: `127.0.0.1` matches `127.0.0.1` only
- Canonicalisation: `EXAMPLE.com` → `example.com`; trailing dot
  stripped; `2852039166` → `127.0.0.1`
- Bare `*` rejected at parse
- `*.com` rejected at parse
- Scheme `http://example.com` rejected at parse

### 6. Evaluator (chain)

`tests/evaluator_test.rs`:

For each stage of the seven-stage chain, a test that:

- Constructs a minimal policy where exactly that stage matches
- Sends an op designed for that stage
- Asserts the resulting `Verdict` has the expected `outcome` and
  `Source`

Plus stage-interaction tests:

- Mandatory-deny shadows a user `allow`: user policy allows `~/.bashrc`
  write, but the bedrock denies
- Stage 2 deny shadows stage 5 session: session has a grant for
  `git push`, but a stage-2 `deny` rule for `git push --force` wins
- Default fallthrough produces `escalate` with the correct
  `amendment_proposal`

### 7. Mandatory-deny

`tests/mandatory_deny_test.rs`:

- Each bedrock pattern denies the canonical write attempt
- `mandatory_deny.write.user_extra` adds patterns; bedrock unaffected
- A user policy `allow` does NOT override bedrock
- Read of bedrock paths is allowed (only write is denied)

### 8. Hook subcommands

`tests/hook_test.rs` (Claude) and `tests/codex_adapter_test.rs` (Codex):

These are the most important integration tests. Each spawns the broker
binary's `hook` subcommand as a subprocess.

For each agent's tool taxonomy:

- Construct a fixture matching the agent's `PreToolUseHookInput` shape
- Spawn `sandbox-broker hook <agent>` with `SANDBOX_BROKER_SOCK` env
  pointed at a test-spawned broker
- Pipe the fixture as stdin
- Capture stdout and exit code
- Assert the parsed `permissionDecision` (Claude) or behaviour (Codex
  silent / JSON / stderr+exit2) matches expectation

Plus failure-mode tests (which exist in the current implementation):

- `SANDBOX_BROKER_ENABLED=0` → exit 0 silent / allow JSON
- Socket missing → exit 0 (passthrough)
- Socket exists but no listener → exit 0 (passthrough)
- Broker returns malformed JSON → fail-open / fail-closed per
  `runtime.fail_open_on_hook_error`

### 9. Lifecycle

`tests/lifecycle_test.rs`:

- `start` daemonises and exits 0; child process running
- `start` followed by another `start` → second exits 1 with "already
  running"
- Stale PID file (file exists, PID dead): `start` cleans up and runs
- `stop` sends SIGTERM; broker drains in-flight RPCs (test by sending
  a slow `/evaluate` from another thread and observing it completes)
- `stop` after dead broker: removes stale socket, exits 0
- SIGHUP reloads policy: edit policy.toml mid-flight, send SIGHUP,
  observe new rule effective
- Cleanup stack runs on SIGTERM: socket file gone, PID file gone

### 10. Templates

`tests/templates_test.rs`:

For each built-in template:

- Loads without parse error
- All examples in all `[[commands]]` rules match their patterns
- All `not_examples` don't match
- Round-trips: parse → serialize → parse equal
- A fixture of expected `(operation, verdict)` pairs

### 11. Audit

`tests/audit_test.rs`:

- Ring buffer push/snapshot
- Ring buffer respects capacity (oldest dropped)
- JSONL writer round-trips
- Rotation at 10 MB threshold
- `explain` reproduces the verdict the daemon emitted (offline replay
  matches live evaluation)

### 12. End-to-end

`tests/e2e.rs`:

The big test that wires it all together. Spawns the broker daemon in
foreground, lets it bind a unique socket in `tempdir()`, then spawns
the `hook claude` subprocess pointed at it, sends a fixture, asserts
the entire path. Catches the integration regressions every test above
might miss.

## Per-Phase test addition

| Phase | Categories added |
|---|---|
| 1.0 (scaffold) | none (placeholder tests pass) |
| 1.1 (policy/matcher) | 1, 2, 3, 4, 5 |
| 1.2 (evaluator) | 6, 7 |
| 1.3 (server/lifecycle) | 9 |
| 1.4 (hooks) | 8 |
| 1.5 (templates/audit) | 10, 11 |
| 1.6 (Nix rewire) | 12 |
| Phase 2 | extends-paths to category 2; `audit log --since` to 11; mandatory-deny hook embedding to 7 |
| Phase 3 | wrap_allowed_bash to 8 (mock landrun); egress proxy E2E to 12 |

## Reuse of existing test corpus

The existing `tests/hook_test.rs` and `tests/codex_adapter_test.rs`
fixtures (`fixture()`, `codex_fixture()`) and helpers (`run_hook`,
`run_codex_hook`, `start_broker_at`) translate directly:

- `start_broker_at(sandbox_dir)` becomes "start the new daemon at this
  path", same return type (socket path).
- `run_hook(sock, input)` becomes "spawn `sandbox-broker hook claude`
  with `SANDBOX_BROKER_SOCK=sock` env", same semantics.
- The fixture JSON shape is identical (Claude / Codex hook input
  schemas haven't changed).

Estimated reuse: ~70% of existing test code carries over. The
deletion of `.sh` adapters means fewer environment-variable corner
cases to test (no shell escaping, no `set -e` interactions).

## Test runtime budget

Phase 1 target: full `cargo test` runs in **under 30 seconds** on the
maintainer's laptop. This is enforced by:

- Unit tests are pure / synchronous where possible
- Integration tests share `start_broker_at` setup helpers that boot a
  broker in <100ms (capability probe is mocked in tests)
- E2E tests use `tempdir()` per test to avoid coordination
- Hook tests use `tokio::test` with shared runtime where appropriate

If a test takes >5 seconds, it's a candidate for splitting or for
moving behind a `--test-threads=1` integration tier.

---

## Key design decisions

- **Layered axes (parse / verdict / lifecycle), each its own file**.
  When a test fails, the file path tells you which layer broke.

- **White-box library tests where the surface allows**. `policy::parse`
  is a function; testing it directly is faster and more precise than
  spawning the binary.

- **Black-box subprocess tests for the hook adapters**. The hook entry
  point is a subprocess in production; testing it as a subprocess
  catches argv-parsing, stdin-reading, and exit-code regressions that
  in-process tests don't.

- **Templates have unit tests of their own**. A template that doesn't
  validate is a shipped bug; CI catches it.

- **Audit tests verify offline `explain` matches live verdicts**.
  Because users will use `explain` to debug; if it diverges from the
  live evaluator, the debugging is misleading.

- **30-second test budget**. Tests run on every commit (pre-push hook
  in dotfiles); slow tests block the dev loop.
