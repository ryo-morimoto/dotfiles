# Hook subcommand adapters

## Design overview

The hooks layer is what the AI agent's runtime actually calls. Claude
Code and Codex invoke a subprocess per tool call, pass the tool's
metadata as JSON on stdin, and read a permission decision from stdout.
The two agents use slightly different JSON shapes; we collapse the
difference into a **shared evaluator** behind two **per-agent shape
adapters** that are subcommands of the broker binary.

Key decisions:

- **Two `hook` subcommands of the broker binary**:
  `sandbox-broker hook claude` and `sandbox-broker hook codex`. The
  legacy `claude-code-hook.sh` and `codex-hook.sh` shell scripts are
  removed.
- **Shared evaluator in Rust** (`hook::shared`). Translation from
  agent-specific JSON to internal `Operation`, the call to the running
  broker over UDS, and translation of `Verdict` to the agent-specific
  response shape are all in one Rust module per direction.
- **Fail-open on broker outage**. If the broker is not running, returns
  malformed JSON, or exceeds the timeout, the hook subcommand returns
  the agent's "allow" shape (or silent exit-0 for Codex). The broker
  outage must not brick the agent session. Borrowed from
  [Codex hooks](./refs/codex.md#hook-system-pretooluse).
- **Tool classification at the hook layer**. Read / Edit / Write /
  Bash → `Operation`; Glob / Grep / WebFetch / MCP / etc. →
  short-circuit allow without consulting the broker.

![Hook adapter shape: per-agent thin shell, shared core](./diagrams/hook-adapter.svg)

## Subcommand entry points

```text
sandbox-broker hook claude   < <agent json on stdin>   > <permission json>
sandbox-broker hook codex    < <agent json on stdin>   > <permission json or empty>
```

Both subcommands:

1. Read all of stdin (single JSON object).
2. Run common preflight: `SANDBOX_BROKER_ENABLED == "1"`?, project root
   resolution (`git rev-parse --git-common-dir`-equivalent), socket path
   discovery.
3. Call `hook::claude::translate` / `hook::codex::translate` to convert
   the agent's tool JSON to an internal `Operation` (or `None` for
   tool-classifier short-circuits).
4. If `Operation` produced: POST `/evaluate` over UDS with a 2-second
   timeout (configurable via `runtime.hook_timeout_ms`).
5. Decode the `Verdict`. Translate to agent-specific response via
   `hook::claude::format_response` / `hook::codex::format_response`.
6. Write JSON to stdout, exit 0.
7. On any error path (timeout, decode failure, missing socket), apply
   the fail-open / fail-closed rule per `runtime.fail_open_on_hook_error`.

## Claude adapter

### Input (stdin)

[`PreToolUseHookInput`](https://docs.claude.com/api/hooks#pretooluseinput)
from `@anthropic-ai/claude-agent-sdk`:

```json
{
  "session_id": "...",
  "transcript_path": "/tmp/...",
  "cwd": "/home/user/project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Read",
  "tool_input": { "file_path": "./src/main.rs" },
  "tool_use_id": "toolu_..."
}
```

### Tool classification

```rust
match tool_name {
    "Read"           => translate_read(&tool_input),     // FileRead
    "Edit" | "Write" => translate_write(&tool_input),    // FileWrite
    "Bash"           => translate_bash(&tool_input),     // CommandExec
    "Glob" | "Grep" | "WebFetch" | "WebSearch"
                     => return ShortCircuit::Allow,
    name if name.starts_with("mcp__")
                     => return ShortCircuit::Allow,
    _                => return ShortCircuit::Allow,      // unknown tools default-allow
}
```

Translation specifics:

- `Read.file_path` → `Operation::FileRead { path: <normalised> }`
- `Edit.file_path`, `Write.file_path` → `Operation::FileWrite { path }`
- `Bash.command` (string) → tokenise via shellwords, take first token
  as binary, full argv as `Operation::CommandExec { argv }`. Shell
  metacharacters (`&&`, `|`, `;`, subshells) → produce a single
  `CommandExec` with the full string as `argv[0..]` and a flag
  `argv_complex: true` so the matcher can decline to make a confident
  decision and force escalate.

### Output (stdout)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow" | "deny" | "ask",
    "permissionDecisionReason": "sandbox-broker: <rationale>"
  }
}
```

`permissionDecision`:

- `Verdict::Allow` → `"allow"` with `reason = rationale_or_default`
- `Verdict::Deny` → `"deny"` with `reason = rationale`
- `Verdict::Escalate` → `"ask"` with `reason = rationale +
  amendment_proposal_hint`

Exit code is always 0 unless internally fatal (panic, broken stdin).
On panic the Claude runtime treats nonzero as `deny`, which is
fail-closed; we don't want this for normal outage so the fail-open
codepath uses exit 0 with `permissionDecision = allow`.

## Codex adapter

### Input (stdin)

[Codex `PreToolUse`](https://developers.openai.com/codex/hooks#pretooluse)
hook input:

```json
{
  "session_id": "...",
  "turn_id": "...",
  "transcript_path": null,
  "cwd": "/home/user/project",
  "model": "gpt-5.5",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": ["ls", "-la"] },
  "tool_use_id": "call_..."
}
```

Notable differences from Claude:

- `Bash.command` is `["ls", "-la"]` (array), not `"ls -la"` (string)
- `tool_name` set is different: `Bash`, `read_file`, `apply_patch`,
  `list_dir`, `web_search`, `mcp_tool`, etc.
- `transcript_path` may be null
- Optional `model`, `turn_id`

### Tool classification

```rust
match tool_name {
    "Bash"        => translate_bash_array(&tool_input),    // CommandExec
    "read_file"   => translate_read(&tool_input.path),     // FileRead
    "list_dir"    => translate_read(&tool_input.path),     // FileRead
    "apply_patch" => translate_apply_patch(&tool_input),   // FileWrite (extracts path from patch or files[])
    "web_search"  => return ShortCircuit::Allow,
    "mcp_tool" | name if name.starts_with("mcp__")
                  => return ShortCircuit::Allow,
    _             => return ShortCircuit::Allow,
}
```

`apply_patch` translation: prefer `tool_input.files[0]` if present,
else parse the patch text for `+++ b/<path>` first hit. Normalise to
`./` prefix.

### Output (stdout)

Codex uses the same Claude-compatible wire shape (Codex deliberately
mirrored Claude's settings shape), but with different consumption:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow" | "deny",
    "permissionDecisionReason": "..."
  }
}
```

Differences in semantics:

| Verdict | Claude exit | Codex exit |
|---|---|---|
| `Allow` | `permissionDecision: allow` JSON, exit 0 | **Silent exit 0** (Codex ignores `allow` in JSON) |
| `Deny`  | `permissionDecision: deny` JSON, exit 0 | `permissionDecision: deny` JSON, exit 0 |
| `Escalate` (`ask`) | `permissionDecision: ask` JSON, exit 0 | **`permissionDecisionReason` to stderr, exit 2** (Codex parses `ask` but fails open; exit 2 reliably blocks) |

The Codex adapter handles the inversion: it emits the JSON only for
`deny`; for `allow` it stays silent; for `escalate` it switches to
`stderr + exit 2` to actually block. Borrowed from the existing
`codex-hook.sh` and validated against
[`refs/codex.md`](./refs/codex.md#hook-system-pretooluse).

## `hook::shared`

```rust
pub struct HookContext {
    pub project_root: PathBuf,           // base repo root
    pub socket_path: PathBuf,
    pub broker_enabled: bool,
    pub timeout: Duration,
    pub fail_open_on_error: bool,
}

pub enum HookResult {
    Decision(Verdict),
    ShortCircuit(ShortCircuit),  // Allow / Deny without broker call
    Error(HookError),            // socket missing, timeout, decode error
}

pub fn evaluate(
    ctx: &HookContext,
    op: Operation,
) -> Result<Verdict, HookError> {
    let body = serde_json::to_vec(&op)?;
    let response = uds_post(&ctx.socket_path, "/evaluate", &body, ctx.timeout)?;
    let verdict: Verdict = serde_json::from_slice(&response)?;
    Ok(verdict)
}
```

Both adapter subcommands call `hook::shared::evaluate`. The result is
fed into the per-agent `format_response`.

## Failure modes

The hook subcommands have several failure modes; each has a specified
behaviour.

| Condition | Claude behaviour | Codex behaviour |
|---|---|---|
| `SANDBOX_BROKER_ENABLED == "0"` | exit 0, allow JSON | exit 0 silent |
| Broker socket file missing | exit 0, allow JSON (passthrough) | exit 0 silent |
| Broker reachable but `/evaluate` times out | exit 0, allow if `fail_open_on_hook_error`; else deny | exit 0 silent if fail-open; else stderr+exit 2 |
| Broker returns invalid JSON | same as timeout | same |
| Broker returns valid `Verdict::Deny` | exit 0, deny JSON with rationale | exit 0, deny JSON with rationale |
| Broker returns valid `Verdict::Escalate` | exit 0, ask JSON | stderr+exit 2 |
| Tool classifier short-circuits | exit 0, allow JSON immediately | exit 0 silent immediately |
| Adapter panic / decode error on stdin | exit non-zero (fail-closed by Claude / Codex semantics) | exit non-zero |

The "broker socket missing → passthrough" branch is the **major UX
fix** vs the existing implementation, where missing socket meant deny.
This is the change that unblocks running an agent in a project that
hasn't run `sandbox-broker init`.

## Tool classification table

| Agent | Tool name | Operation | Notes |
|---|---|---|---|
| Claude | `Read` | `FileRead` | path from `file_path` |
| Claude | `Edit` | `FileWrite` | path from `file_path` |
| Claude | `Write` | `FileWrite` | path from `file_path` |
| Claude | `Bash` | `CommandExec` | command from `command` (string), shellwords-tokenise |
| Claude | `Glob`, `Grep` | (short-circuit allow) | not policy-controlled |
| Claude | `WebFetch`, `WebSearch` | (short-circuit allow) | network egress; broker doesn't enforce here in Phase 1 |
| Claude | `mcp__*` | (short-circuit allow) | MCP tool calls are out of scope |
| Codex | `Bash` | `CommandExec` | argv from `command` (array, not string) |
| Codex | `read_file` | `FileRead` | path from `path` |
| Codex | `list_dir` | `FileRead` | dir listing treated as read |
| Codex | `apply_patch` | `FileWrite` | path from `files[0]` or patch parse |
| Codex | `web_search` | (short-circuit allow) | |
| Codex | `mcp_tool`, `mcp__*` | (short-circuit allow) | |

`WebFetch` / `WebSearch` are NOT translated to `Operation::Connect` at
Phase 1 because the agent's tool already takes care of egress and we
don't want to double-prompt. Phase 3 may revisit when an egress proxy
ships.

---

## Key design decisions

- **Subcommands of the broker binary, not standalone scripts**. One
  versioned artifact, no shell script / Rust binary version skew. The
  Nix `commandFn` wires `home/agents/default.nix` to the binary's
  subcommand directly.

- **Per-agent translation lives in `hook::{claude,codex}`**. Adding a
  third agent (Cursor, Cline, Roo Code) means writing a third
  translator + format module, not touching the evaluator. Borrowed
  from [Fence's per-agent adapter pattern](./refs/fence.md).

- **Fail-open on broker outage by default**. The broker is opt-in
  hardening; if it's unreachable, the user's local machine still works.
  `runtime.fail_open_on_hook_error = false` is available for users who
  want strict mode.

- **Codex's `ask`-fail-open is handled at the adapter, not the
  evaluator**. The evaluator emits `Verdict::Escalate` regardless of
  agent; Codex's adapter translates it to `stderr + exit 2` because
  Codex's `permissionDecision: ask` is unsupported (parses but
  fails open). Borrowed from
  [`refs/codex.md`](./refs/codex.md#hook-system-pretooluse).

- **Tool classifier short-circuit before broker call**. Glob, Grep,
  WebFetch, MCP — broker never sees them. Saves the round-trip and
  keeps the broker scope tight (filesystem / network / command).

- **Phase 1 leaves WebFetch / WebSearch alone**. Network policy hooks
  in at the OS layer (egress proxy in Phase 3), not the agent tool
  layer. Don't double-enforce.
