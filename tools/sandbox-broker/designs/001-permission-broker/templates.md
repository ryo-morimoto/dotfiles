# Built-in templates

## Design overview

`sandbox-broker init` writes a `policy.toml` from one of three built-in
templates. The templates are first-class onboarding: a fresh project
is `init`-ed, the broker started, and the typical AI agent operations
work without prompts. Borrowed from
[Fence's `internal/templates/code.json`](./refs/fence.md#policy--config-dsl).

Three templates ship in Phase 1:

- **`code`** — the default. Allow common dev domains, deny secrets and
  cloud metadata, allow read-only git inspection and common build
  commands, escalate on mutating commands.
- **`code-strict`** — same shape with a tighter network allow-list and
  no command auto-allow beyond read-only.
- **`git-readonly`** — read-only git inspection only; useful for
  running an agent against an unfamiliar repo where you want to read
  but not modify.

Templates are stored as `.toml` strings in
`policy::templates::BUILTINS: phf::Map<&str, &str>` (`phf` perfect
hash for compile-time lookup). The `@builtin/<name>` prefix in
`extends` is a lookup into this table.

Key decisions:

- **Three templates, not one**. A single template is either too
  restrictive (annoying defaults) or too permissive (unsafe defaults).
  Differentiating by intended use helps both onboarding and audit.
- **Templates are TOML, not Rust constants**. Stored as `include_str!`
  and parsed at use time. Lets users `cat` the template to see what
  they're inheriting from.
- **Template choice is `extends`-able**. A project policy starts with
  `extends = ["@builtin/code"]` and adds project-specific rules; it
  doesn't fork the template.

## `@builtin/code`

The default for AI agents. Optimized to minimize prompts on read and
common dev tasks while reliably stopping the dangerous things.

```toml
# @builtin/code — default AI agent policy template

[mandatory_deny.write]
user_extra = []                       # bedrock list is always applied

[filesystem.read]
default = "allow"
deny = [
  ".env", ".env.*",
  "**/secrets/**", "**/private/**",
  "~/.ssh/**", "~/.aws/**", "~/.gcp/**",
  "~/.netrc", "~/.npmrc",
  "~/.docker/config.json",
  "**/credentials.json",
]

[filesystem.write]
default = "deny"
allow = [
  "./**",                             # entire workspace
  "/tmp/**",
  "${TMPDIR:-/tmp}/**",
]
deny = [
  "./.env",                           # carve-out within the workspace
  "./.env.*",
  "./.git/hooks/**",                  # belt-and-braces; bedrock also covers this
  "./.claude/**",
  "./.codex/**",
  "./.sandbox/policy.toml",
]

[network]
allow_loopback = true
allow_domains = [
  # AI vendors
  "api.anthropic.com",
  "api.openai.com",
  "generativelanguage.googleapis.com",
  # Code hosting
  "github.com", "*.github.com",
  "gitlab.com",
  "codeberg.org",
  # Package registries
  "registry.npmjs.org", "*.npmjs.org",
  "pypi.org", "files.pythonhosted.org",
  "crates.io", "static.crates.io",
  "registry.yarnpkg.com",
  "rubygems.org",
  "go.dev", "proxy.golang.org", "sum.golang.org",
  # Common docs / refs
  "docs.python.org",
  "developer.mozilla.org",
  "doc.rust-lang.org",
  "stackoverflow.com",
]
deny_domains = [
  # Cloud metadata services
  "169.254.169.254",
  "metadata.google.internal",
  "fd00:ec2::254",
  # Common telemetry endpoints (extend per project)
  "telemetry.posthog.com",
]

[[commands]]
pattern = ["git", ["status", "diff", "log", "show", "branch", "ls-files", "ls-tree", "blame", "remote"]]
decision = "allow"
examples = [["git", "status"], ["git", "log", "--oneline"], ["git", "diff", "HEAD~1"]]
not_examples = [["git", "push"], ["git", "reset", "--hard"]]
justification = "local read-only git inspection"

[[commands]]
pattern = ["git", ["add", "commit", "stash", "checkout", "switch", "pull", "fetch", "merge", "rebase"]]
decision = "ask"
examples = [["git", "commit", "-m", "msg"]]
justification = "git mutations require explicit approval"

[[commands]]
pattern = ["git", "push", "*"]
decision = "ask"
examples = [["git", "push", "origin", "main"]]
justification = "publishing requires explicit approval"

[[commands]]
pattern = ["cargo", ["check", "build", "test", "fmt", "clippy", "doc"]]
decision = "allow"
examples = [["cargo", "check"], ["cargo", "test", "--", "policy"]]
not_examples = [["cargo", "publish"]]
justification = "local Rust build/test"

[[commands]]
pattern = ["cargo", "publish"]
decision = "ask"
examples = [["cargo", "publish"]]
justification = "publishing crates requires approval"

[[commands]]
pattern = [["npm", "pnpm", "yarn", "bun"], ["install", "ci", "run", "test", "build"]]
decision = "allow"
examples = [["npm", "install"], ["bun", "test"], ["pnpm", "run", "build"]]
not_examples = [["npm", "publish"]]
justification = "local JS package manager operations"

[[commands]]
pattern = [["npm", "pnpm", "yarn", "bun"], "publish"]
decision = "ask"
examples = [["npm", "publish"]]
justification = "publishing packages requires approval"

[[commands]]
pattern = [["rg", "fd", "ls", "cat", "head", "tail", "wc", "diff", "grep", "find", "tree"]]
decision = "allow"
examples = [["rg", "TODO"], ["fd", "-e", "ts"]]
justification = "local read-only inspection tools"

[[commands]]
pattern = [["mkdir", "touch", "cp", "mv", "ln"]]
decision = "ask"
examples = [["mkdir", "-p", "src/foo"]]
justification = "filesystem mutation requires approval (paths are checked separately)"

[[commands]]
pattern = ["rm", "*"]
decision = "ask"
examples = [["rm", "foo.txt"]]
justification = "removal requires explicit approval"

[runtime]
daemonize = true
fail_open_on_hook_error = true
wrap_allowed_bash = false
hook_timeout_ms = 2000

[worktree]
allow_siblings = true
```

Use case: a developer using Claude Code or Codex for general coding,
across a project with normal dependencies. Network egress to common
dev services is allowed; secrets and writes outside the workspace are
denied or escalated.

## `@builtin/code-strict`

Tighter form of `code` for security-sensitive work. Differences:

- `network.allow_loopback = false` — connections to localhost require
  explicit allow rules
- `network.allow_domains` is shorter (only registries the project
  actually pulls from; AI vendors only when the agent is configured to
  call out)
- All `cargo` / `npm` / `pnpm` commands are `decision = "ask"` rather
  than `"allow"` — explicit per-invocation approval
- All filesystem writes outside `./` are denied (no `/tmp/**` allow)
- `runtime.fail_open_on_hook_error = false` — broker outage means
  nothing runs

```toml
# @builtin/code-strict — tighter form of @builtin/code

extends = ["@builtin/code"]            # inherit then override

[network]
allow_loopback = false
# Override the @builtin/code allow_domains:
allow_domains = [
  "api.anthropic.com",
  "api.openai.com",
  "github.com", "*.github.com",
  "registry.npmjs.org",                # only npm; remove yarn/pnpm endpoints
  "crates.io", "static.crates.io",
]

[[commands]]
# Append: shadow the @builtin/code allow rules with ask for build tools
pattern = ["cargo", ["check", "build", "test", "fmt", "clippy", "doc"]]
decision = "ask"
examples = [["cargo", "check"]]
justification = "strict mode: explicit approval for builds"

[[commands]]
pattern = [["npm", "pnpm", "yarn", "bun"], ["install", "ci", "run", "test", "build"]]
decision = "ask"
examples = [["npm", "install"]]
justification = "strict mode: explicit approval for package operations"

[runtime]
fail_open_on_hook_error = false
```

Note: `[[commands]]` are appended; the strict rules come *after* the
inherited rules in the merged policy. The matcher iterates rules in
order and the first match wins. Since `@builtin/code` has the allow
rule first, the strict ask rule won't shadow it. **The user is expected
to put strict overrides earlier OR use a separate template that
doesn't extend code**. Phase 2 considers explicit precedence
annotations.

For Phase 1, users wanting strict-without-inheritance write:

```toml
# .sandbox/policy.toml
# don't extend code; declare from scratch
extends = []
# ... strict-only rules ...
```

This is documented in the template comments.

Use case: agent running autonomously on a security-sensitive project,
or against unfamiliar code where you want a per-command audit trail.

## `@builtin/git-readonly`

Bare-minimum read-only access. No network, no writes outside `./.git/`,
only `git` read commands and basic file reads.

```toml
# @builtin/git-readonly — read-only repository inspection

[mandatory_deny.write]
user_extra = []

[filesystem.read]
default = "allow"
deny = [
  ".env", ".env.*",
  "**/secrets/**",
  "~/.ssh/**", "~/.aws/**", "~/.gcp/**",
  "~/.netrc", "~/.npmrc",
]

[filesystem.write]
default = "deny"
allow = []                            # NO write at all

[network]
allow_loopback = false
allow_domains = []
deny_domains = ["169.254.169.254", "metadata.google.internal"]

[[commands]]
pattern = ["git", ["status", "diff", "log", "show", "branch", "ls-files", "ls-tree", "blame", "remote", "config", "describe", "shortlog"]]
decision = "allow"
examples = [["git", "status"], ["git", "log"], ["git", "diff", "HEAD"]]
not_examples = [["git", "push"], ["git", "commit"], ["git", "checkout"]]
justification = "read-only git inspection"

[[commands]]
pattern = [["rg", "fd", "ls", "cat", "head", "tail", "wc", "tree", "find"]]
decision = "allow"
examples = [["rg", "TODO"], ["cat", "README.md"]]
justification = "read-only file inspection"

[runtime]
daemonize = true
fail_open_on_hook_error = false       # in strict modes, broker outage = no run

[worktree]
allow_siblings = true
```

Use case: cloning an unfamiliar repo and asking the agent to summarize
or analyze without any side effects. Even `git fetch` requires explicit
approval.

## Authoring guidance for new templates

A new template should:

1. **Have a clear use case** — one sentence describing who would `extends`
   this template. If it's the same use case as an existing template,
   patch the existing one.

2. **Specify all four schema sections** — `mandatory_deny.write`,
   `filesystem.{read,write}`, `network`, plus `[[commands]]` and
   `[runtime]`. Templates that omit a section make `extends` chains
   confusing because users don't know whether the omission is "default"
   or "use parent".

3. **Have at least three `[[commands]]` rules** with `examples` and
   `not_examples`. Templates with sparse command rules are unhelpful.

4. **Be unit-tested**. A test under `tests/templates_test.rs` loads
   the template and runs a fixture of expected `(operation, verdict)`
   pairs against it.

To add a new template:

1. Write `templates/<name>.toml`
2. Add it to `policy::templates::BUILTINS` in
   `src/policy/templates.rs`
3. Add a fixture test
4. Document in this file

---

## Key design decisions

- **Three templates, not one universal**. Single templates always
  pick wrong defaults for some users. Three covers most use cases
  with explicit choice.

- **Templates are themselves `extends`-able**. `@builtin/code-strict`
  extends `@builtin/code` and tightens. Encourages reuse over
  duplication.

- **Templates ship as `.toml` text, not Rust constants**. `phf::Map<&str,
  &str>` lookup; `policy show` can reproduce them; users can `cat`
  them.

- **`@builtin/code` is permissive enough for first-day usability**.
  Don't make the default template the strict one — users will hit
  prompts immediately and stop using the broker.

- **Templates carry their own `[runtime]` defaults**. Strict and git-readonly
  set `fail_open_on_hook_error = false` because their users opted into
  strictness.
