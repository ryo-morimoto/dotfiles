# Audit and explain

## Design overview

Every verdict the broker emits is recorded with full provenance — the
operation, the source stage of the chain, the rule that matched, the
risk class, and the timestamp. This goes into a **ring buffer** in
memory plus an **append-only log** on disk, both flushed on shutdown.

Three observability surfaces consume this:

- `sandbox-broker log [--since DUR] [--source S]` — dump recent
  verdicts (read from the on-disk log; works even after restart).
- `sandbox-broker explain <op-json>` — replay the chain for a single
  operation and show which rule fired and why. Doesn't need a running
  broker; runs the same evaluator against the on-disk policy.
- `sandbox-broker policy show` — print the resolved policy after
  `extends` merge, with provenance lines (`# from @builtin/code:42`)
  next to each rule.

Key decisions:

- **Ring buffer + append-only log**. The ring buffer is the live
  in-memory window (`log` reads recent verdicts even from a still-running
  broker); the on-disk log is durable history (`log` after a restart
  still works). Phase 1 implements both.
- **Provenance on every verdict**. The `Source` enum is mandatory on
  every `Verdict`; the audit record additionally includes the
  triggering rule (e.g. `commands[3]` or `mandatory_deny.bedrock[5]`).
- **`explain` is offline**. It loads the policy and runs the evaluator
  in the same process; no UDS round-trip. Lets users debug policies
  without a running broker.

## Audit record schema

```rust
pub struct AuditRecord {
    pub timestamp: DateTime<Utc>,
    pub operation: Operation,
    pub verdict: Verdict,
    pub rule_pointer: Option<RulePointer>,
    pub session_id: Option<String>,         // from the agent's hook input
    pub tool_use_id: Option<String>,        // for correlation
}

pub enum RulePointer {
    MandatoryDenyBedrock(usize),            // index into BEDROCK
    MandatoryDenyUserExtra(usize),          // index into user_extra
    PolicyCommand(usize),                   // index into [[commands]]
    PolicyFilesystemReadAllow(usize),
    PolicyFilesystemReadDeny(usize),
    PolicyFilesystemWriteAllow(usize),
    PolicyFilesystemWriteDeny(usize),
    PolicyNetworkAllow(usize),
    PolicyNetworkDeny(usize),
    SessionGrant(usize),
    Programmatic(&'static str),             // e.g. "hidden-file-write"
    DefaultFallthrough,
}
```

The `RulePointer` resolves to a specific config-file location for the
human to look at. `policy show` and `explain` render this as `policy.toml:42`
or `@builtin/code:128` after the merge provenance is consulted.

## Ring buffer

In-memory, fixed capacity (default 4096 records, configurable via
`runtime.audit_ring_capacity`).

```rust
pub struct RingBuffer<T> {
    inner: parking_lot::Mutex<VecDeque<T>>,
    capacity: usize,
}

impl<T> RingBuffer<T> {
    pub fn push(&self, x: T) {
        let mut q = self.inner.lock();
        if q.len() == self.capacity { q.pop_front(); }
        q.push_back(x);
    }
    pub fn snapshot(&self) -> Vec<T> where T: Clone {
        self.inner.lock().iter().cloned().collect()
    }
}
```

Borrowed from
[`sandbox-runtime`'s `sandbox-violation-store.ts`](./refs/sandbox-runtime.md#notable-design-ideas).

## On-disk log

`<base>/.sandbox/audit.log`. Append-only, line-delimited JSON, rotated
when it exceeds 10 MB (rotation: rename to `audit.log.1`, drop
`audit.log.10`).

```jsonl
{"ts":"2026-04-30T12:00:01.234Z","op":{"kind":"FileRead","detail":{"path":"./src/main.rs"}},"verdict":{"outcome":"allow","source":"PolicyMatch","risk":"low","rationale":""},"rule":"PolicyFilesystemReadAllow:0","session_id":"..."}
{"ts":"2026-04-30T12:00:01.456Z","op":{"kind":"CommandExec","detail":{"argv":["git","push","origin","main"]}},"verdict":{"outcome":"escalate","source":"PolicyMatch","risk":"medium","rationale":"publishing requires confirmation","amendment_proposal":{"kind":"AppendCommand","pattern":["git","push","origin","main"],"decision":"allow"}},"rule":"PolicyCommand:7","session_id":"..."}
```

JSONL choice: line-by-line streaming, easy `tail -f`, easy `jq` post-processing.

Writes are async; the audit task receives records over a tokio mpsc
channel from the request handler. On shutdown, the channel drains and
writes are flushed.

## `log` subcommand

```
sandbox-broker log [--since 1h] [--source PolicyMatch] [--outcome deny]
                   [--limit 50] [--format pretty|json]
```

Reads `audit.log[.N]` (newest-first within each file, files in reverse
chronological order). Filters apply post-read.

Pretty format:

```
12:00:01 ALLOW   FileRead  ./src/main.rs                          policy.toml#read.allow:0
12:00:01 ASK     CommandExec git push origin main                policy.toml#commands:7  (publishing requires confirmation)
12:00:02 DENY    FileWrite ~/.bashrc                              mandatory-deny:bedrock:0
```

The provenance trailing column is the `RulePointer` resolved to a
config location.

## `explain` subcommand

```
sandbox-broker explain '{"kind":"CommandExec","detail":{"argv":["git","push","origin","main"]}}'

policy chain trace for: CommandExec ["git", "push", "origin", "main"]

  stage 1 mandatory_deny      → NoMatch (operation kind not write/delete)
  stage 2 policy.commands     → MATCH at policy.toml#commands:7
                                 pattern: ["git", "push", "*"]
                                 decision: ask
                                 justification: publishing requires confirmation
  stage 3-7                   → not consulted (stage 2 short-circuits)

verdict: Escalate (source=PolicyMatch, risk=medium)
amendment proposal:
  --- /dev/null
  +++ policy.toml
  @@ +N,0 @@
  +[[commands]]
  +pattern = ["git", "push", "origin", "main"]
  +decision = "allow"
  +examples = [["git", "push", "origin", "main"]]
  +justification = "approved 2026-04-30 by user"
```

Implementation: `explain` loads the policy, builds the same `Evaluator`
the daemon uses, and calls `evaluator.evaluate_traced(&op)` which
returns `(Verdict, ChainTrace)`. The trace is a per-stage record of
`MatchResult` for that stage's matchers.

This is offline — no UDS round trip — so users can iterate on policy
edits without restarting the broker.

## `policy show`

```
sandbox-broker policy show [--format pretty|toml]

resolved policy: <base>/.sandbox/policy.toml

extends chain:
  1. @builtin/code (built-in)
  2. ./team-overrides.toml
  3. (this file)

[mandatory_deny.write]
# from build-time bedrock (cannot be removed)
bedrock = [
  "**/.bashrc",
  "**/.zshrc",
  ...
]
# from .sandbox/policy.toml:line-3
user_extra = ["**/.aws/credentials"]

[filesystem.read]
default = "allow"
# from @builtin/code:25
deny = [".env", ".env.*", "**/secrets/**", ...]
# from ./team-overrides.toml:8
deny += ["**/private-keys/**"]                     # appended
# from .sandbox/policy.toml:12
allow = ["~/.ssh/known_hosts"]                     # appended

[[commands]]
# from @builtin/code:88
pattern = ["git", ["status", "diff", "log", ...]]
decision = "allow"
...
```

The `# from <source>:<line>` comment makes provenance explicit. The
`+= [...]` annotation shows append vs replace per merge semantics.

`--format toml` emits a clean TOML without comments — useful for
copy-pasting the resolved policy as a single-file deployment.

## Amendment proposals

When the verdict is `Escalate` and the human approves "allow this and
remember", the broker can emit a deterministic policy diff:

```rust
pub enum PolicyAmendment {
    AppendCommand {
        pattern: Vec<PrefixToken>,
        decision: Decision,                  // typically Allow
        examples: Vec<Vec<String>>,
    },
    ExtendFilesystemAllow {
        category: FilesystemCategory,        // Read or Write
        pattern: String,
    },
    ExtendNetworkAllow {
        domain: String,
    },
}
```

The proposal is generated by `evaluator::propose_amendment(&op)` based
on the operation kind. For a `CommandExec` that fell through to
escalate, the proposal is `AppendCommand` with the operation's argv
collapsed into a pattern (first token fixed, rest as `Fixed`). The
human sees the proposal in the verdict's `amendment_proposal` field.

Borrowed from
[Codex's `proposed_execpolicy_amendment`](./refs/codex.md#approval-policy-dsl).

Phase 1 ships **proposal generation only**. Application is manual: the
human reads the proposal, decides, and edits `policy.toml`. Phase 2
adds a `sandbox-broker policy amend <id>` subcommand that applies
recently-proposed amendments interactively.

---

## Key design decisions

- **Provenance on every record**. `RulePointer` is mandatory on the
  audit record (None only for the default-fallthrough case); humans
  can always answer "which line of which file caused this verdict".
  Borrowed from [Codex's `HookSource`](./refs/codex.md#verdict-flow).

- **Ring buffer plus on-disk log, both**. The ring is for live
  inspection (low latency, no IO); the disk log is for restart
  durability and external tooling (`tail -f`, `jq`). They share one
  schema.

- **`explain` is offline by design**. Lets users iterate on policy
  edits without bouncing the broker. Same evaluator code path — no
  divergence between live verdicts and explained ones.

- **Amendment proposals as first-class verdict field**. Codex showed
  this is the right UX: human's "remember" answer becomes a reviewable
  diff, not an opaque side-effect.

- **JSONL on disk, structured pretty in CLI**. `cat audit.log | jq`
  works; `sandbox-broker log` formats for humans. No custom binary
  format.
