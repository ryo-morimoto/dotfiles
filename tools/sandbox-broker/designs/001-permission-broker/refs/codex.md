# OpenAI Codex CLI

## Summary

Codex CLI ships a **multi-layer permission system** combining (a) a typed `SandboxPolicy` enforced by a platform sandbox runtime (Seatbelt / bwrap+Landlock+seccomp / Windows restricted token), (b) a Starlark-based `execpolicy` DSL of `prefix_rule` / `network_rule` decisions consulted before approval, and (c) a Claude-Code-compatible hook engine that fires `PreToolUse` / `PermissionRequest` / `PostToolUse` etc. in subprocess form. Approval (`approval_policy`) and sandbox (`sandbox_mode`) are **two orthogonal axes** layered on top of these.

## Architecture

Three Rust crates carry the load:

- `codex-rs/sandboxing/` — runtime selector and transformer. Picks `SandboxType` (Seatbelt / LinuxSeccomp / WindowsRestrictedToken / None) from a `PermissionProfile` and wraps the user command. Source: `codex-rs/sandboxing/src/manager.rs`, `policy_transforms.rs`.
- `codex-rs/execpolicy/` — Starlark DSL for declarative `prefix_rule()` / `network_rule()` matchers returning `Decision::Allow | Prompt | Forbidden`. Source: `codex-rs/execpolicy/src/{rule.rs,decision.rs,parser.rs,amend.rs}`.
- `codex-rs/hooks/` — `ClaudeHooksEngine`, which discovers `hooks.json` / `[hooks]` TOML across config layers, dispatches by event + matcher regex, and runs each handler as a subprocess with JSON on stdin. Source: `codex-rs/hooks/src/{engine/, events/, schema.rs, registry.rs}`.

Outer process is the agent (`codex-tui`, `codex-exec`, `codex-mcp-server`); the linux-sandbox is invoked as a child helper binary (`codex-rs/linux-sandbox/src/linux_run_main.rs`).

## Sandbox Modes

`SandboxMode` (`codex-rs/protocol/src/config_types.rs:68`) — the user-facing TOML enum:

- `read-only` (default)
- `workspace-write`
- `danger-full-access`

Internally those expand into the richer `SandboxPolicy` (`protocol/src/protocol.rs:1028`):

- `ReadOnly { network_access }`
- `WorkspaceWrite { writable_roots, network_access, exclude_tmpdir_env_var, exclude_slash_tmp }`
- `ExternalSandbox { network_access }` — already in container, skip our sandbox
- `DangerFullAccess`

Platform implementation (`sandboxing/src/manager.rs:48`):

- macOS → **Seatbelt** (`sandbox-exec`, base policy in `seatbelt_base_policy.sbpl` + composed network policy)
- Linux → **bwrap (bubblewrap) + Landlock + seccomp**, executed via the `codex-linux-sandbox` helper. Bubblewrap is now default; Landlock is `--use-legacy-landlock` fallback (`linux-sandbox/src/linux_run_main.rs:52`). bwrap also handles managed-network proxy routing (`proxy_routing.rs`).
- Windows → restricted-token only when `windows_sandbox_level != Disabled`.

Selection logic in `SandboxManager::select_initial` (`manager.rs:139`) honours a `SandboxablePreference::{Auto,Require,Forbid}` and `should_require_platform_sandbox` (`policy_transforms.rs:509`) — e.g. an `ExternalSandbox` short-circuits to no extra wrapping, and `WorkspaceWrite` with full disk access skips bwrap.

## Approval Policy DSL

Two TOML keys at the top of `~/.codex/config.toml` (and overridable per-profile via `profile_toml.rs:31`):

```toml
approval_policy = "on-request"   # or untrusted | on-failure | never | { type = "granular", ... }
sandbox_mode    = "workspace-write"
```

`AskForApproval` enum (`protocol/src/protocol.rs:934`):

- `untrusted` — only "known safe" read-only commands auto-approve; everything else asks
- `on-failure` (deprecated) — auto-run inside sandbox; on sandbox failure escalate to user
- `on-request` (default) — model decides when to ask
- `never` — never prompt; failures returned to model
- `granular { sandbox_approval, rules, skill_approval, request_permissions, mcp_elicitations }` — fine-grained switches; `false` field means *auto-reject* that class without prompting

Per-MCP-server overrides live under `[mcp_servers.<name>]` with `default_tools_approval_mode` and per-tool `approval_mode` (`docs/config.md:29`).

**execpolicy prefix-rule DSL** (Starlark, `execpolicy/src/parser.rs:347`):

```python
prefix_rule(
    pattern=["git", ["status", "diff", "log"]],   # alternatives in nested list
    decision="allow",                              # allow | prompt | forbidden
    match=[["git", "status"]],                     # positive examples (validated)
    not_match=[["git", "push"]],                   # negative examples
    justification="local read-only inspection",
)

network_rule(
    host="api.github.com",
    protocol="https",                              # http|https|socks5_tcp|socks5_udp
    decision="allow",
    justification="release tooling",
)
```

`PrefixPattern.first` is a fixed string used for index lookup; `rest` is `[PatternToken::Single | PatternToken::Alts]`. Matching is tokenwise prefix on argv (`rule.rs:46`). Hosts are normalised lowercase, no wildcards, no scheme/path. The amend module appends new `prefix_rule(..., decision="allow")` lines back to the policy file when the user clicks "approve and remember" (`amend.rs:65`).

## Hook System (PreToolUse, PostToolUse, …)

Six events: `PreToolUse`, `PermissionRequest`, `PostToolUse`, `SessionStart`, `UserPromptSubmit`, `Stop` (`hooks/src/schema.rs:71`). Codex follows the **Claude Code wire shape** so the same hooks are portable.

Config — both supported, JSON wins on collision warning (`engine/discovery.rs:72`):

- `~/.codex/hooks.json` (shape compatible with Claude Code's `settings.json` `hooks` block):

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "^Bash$",
        "hooks": [
          { "type": "command",
            "command": "python3 /tmp/pre.py",
            "timeout": 10,
            "statusMessage": "checking" }
        ]
      }
    ]
  }
}
```

- `[[hooks.PreToolUse]]` table arrays inside `config.toml` (`config/src/hooks_tests.rs:52`).

Layers (lowest → highest precedence): `System → Mdm → User → Project → SessionFlags`, plus a managed-requirements layer prepended (`engine/discovery.rs:67`). Plugins also contribute `hooks/hooks.json`.

**Stdin payload** — `PreToolUseCommandInput` (`schema.rs:215`):

```json
{
  "session_id": "...", "turn_id": "...", "transcript_path": null,
  "cwd": "/repo", "hook_event_name": "PreToolUse",
  "model": "gpt-5", "permission_mode": "default",
  "tool_name": "Bash", "tool_input": { "command": "..." },
  "tool_use_id": "call_..."
}
```

**Stdout decision** (`schema.rs:183`):

```json
{ "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",          // allow | deny | (ask is parsed but unsupported, fails open)
    "permissionDecisionReason": "..."
}}
```

Exit code 2 with reason on stderr is also honoured for blocking; legacy `{"decision":"block"}` still works (`events/pre_tool_use.rs:197,313`). Multiple hooks run in parallel via `join_all`; **any deny wins, last allow wins for `PermissionRequest`** (`events/permission_request.rs:148`).

## Verdict Flow

For a shell command, the agent resolves in roughly this order:

1. **execpolicy** matches argv → `Allow` / `Prompt` / `Forbidden` (`execpolicy/src/policy.rs`). `Forbidden` aborts, `Allow` skips approval entirely.
2. **`approval_policy`** decides whether `Prompt` (or "needs approval" verdicts) become an interactive prompt or an auto-reject (e.g. `never` → reject; `untrusted` → prompt unless safe).
3. **`PreToolUse` hooks** fire next; `permissionDecision: deny` (or exit 2) blocks with feedback to the model. `additionalContext` / `ask` are unsupported and fail open today.
4. **`PermissionRequest` hooks** fire only when an approval prompt is about to be shown — they can short-circuit allow/deny and skip the human (`PermissionRequestBehaviorWire::{Allow,Deny}`, `schema.rs:160`).
5. Otherwise the **GuardianReviewer** subagent (`ApprovalsReviewer::AutoReview`) or the **user** reviews; outcome can also propose a new `prefix_rule(..., decision="allow")` amendment to remember the answer (`approvals.rs:32-58`).
6. Approved command runs inside the picked **SandboxType**; on sandbox failure with `OnFailure` policy the agent escalates to the user.

`HookSource::{User,Project,Plugin,Managed}` is recorded so audit logs can show which layer produced the verdict.

## Daemon / Process Model

**No daemon.** The agent process is long-lived; sandboxing is per-exec — each shell tool call spawns `codex-linux-sandbox` (or `sandbox-exec`) → command. Hooks are shelled out per event with a configurable shell (`HooksConfig.shell_program`). One semi-persistent process exists: the **shell-escalation server** (`shell-escalation/src/unix/escalate_server.rs`) — a unix-socket helper that lets in-sandbox `execve` intercepts ask the parent agent for approval without leaving the sandbox.

## Failure Modes

- **bwrap unavailable** → `Wsl1UnsupportedForBubblewrap` / `MissingLinuxSandboxExecutable` errors map to `CodexErr::LandlockSandboxExecutableNotProvided` / `UnsupportedOperation` (`sandboxing/src/lib.rs:32`); user must install bwrap or pass `--use-legacy-landlock`.
- **Hook subprocess error / non-0/non-2 exit** → `HookRunStatus::Failed`, *fails open* (does not block), but writes an error entry into the transcript.
- **Hook returns unsupported `permissionDecision: ask` or unknown `additionalContext`** → fails open with a `Failed` status (`events/pre_tool_use.rs:343-423`).
- **execpolicy parse error** → loaded policy is rejected, falls back to non-execpolicy approval flow.

## Notable Design Ideas

- **Two-tier verdict separation**: `execpolicy` declarative prefix matching is a *static* layer; hooks are *dynamic*. Avoids forcing all logic into one shape.
- **Prefix amendments as first-class UX**: the approval prompt carries `proposed_execpolicy_amendment` so the user's "allow next time" answer is durable, machine-checkable, and reviewable as a patch (`approvals.rs:32`, `amend.rs:65`).
- **Layered config stack with explicit MDM/managed-requirements**: enterprise can pin `allowed_sandbox_modes = ["read-only"]` and `allowed_approval_policies` (`config_requirements.rs:629`) so end-user config can only weaken-within-allowed.
- **Fail-open on unknown hook output**: prevents a buggy hook from bricking the whole agent; failure mode is "log + continue" rather than "deny + halt".
- **Compatibility-first hook wire**: deliberately mirrors Claude Code's `settings.json` hook block + `permissionDecision` payload; the same hook scripts work on both clients (`schema.rs` documents this).

## Differences vs Claude Code

- **Config format**: Codex prefers TOML (`[hooks]` array-of-tables in `config.toml`) but also accepts the Claude `hooks.json` JSON shape. Claude Code uses `settings.json` exclusively.
- **Decision representation**: Codex has *three* primitives — execpolicy `Decision::{Allow, Prompt, Forbidden}`, hook `permissionDecision: {allow, deny}`, and `approval_policy` modulating the human step. Claude Code collapses to `permissionDecision: {allow, deny, ask}`. Codex parses `ask` but treats it as `Failed` (fails open).
- **Static rule DSL**: Codex bundles a Starlark policy language with positive/negative examples that are validated at parse time; Claude Code has nothing equivalent in-tree.
- **Sandbox runtime is owned, not delegated**: Codex ships `codex-linux-sandbox` (bwrap + Landlock + seccomp) and Seatbelt profiles; Claude Code relies on the OS or external tooling for actual confinement.
- **Two-tier approval**: `PreToolUse` (block-or-allow-the-call) is distinct from `PermissionRequest` (decide-the-prompt). Claude Code only has the former.

## Anti-Patterns / Caveats

- `permissionDecision: "ask"` is parsed but **not honoured** (fails open) — surprising for users porting Claude hooks.
- Hooks default to **fail-open** on subprocess errors. Safe for availability, dangerous if a hook is the only line of defence — broker should consider fail-closed by default for security-critical events.
- `approval_policy = "on-failure"` is deprecated and discouraged because it turns sandbox failures into surprise user prompts; design docs steer to `on-request` or `never`.
- Glob filesystem entries only support **deny-read** (`policy_transforms.rs:33`) — there's no glob allow-write. Worth noting if mimicking prefixRules over paths.

## Key File Pointers

- Sandbox enums: `codex-rs/protocol/src/config_types.rs:68` (`SandboxMode`), `codex-rs/protocol/src/protocol.rs:934` (`AskForApproval`), `:1028` (`SandboxPolicy`)
- Sandbox runtime selection: `codex-rs/sandboxing/src/manager.rs:48,139,168`
- Permission/glob transforms: `codex-rs/sandboxing/src/policy_transforms.rs:125,239,290,509`
- Linux helper entry: `codex-rs/linux-sandbox/src/linux_run_main.rs:96`
- macOS Seatbelt policies: `codex-rs/sandboxing/src/seatbelt_base_policy.sbpl`, `seatbelt_network_policy.sbpl`
- Execpolicy DSL: `codex-rs/execpolicy/src/parser.rs:347` (`prefix_rule`/`network_rule` builtins), `rule.rs:39` (`PrefixPattern`), `decision.rs:9`, `amend.rs:65`
- Default policy seed: `codex-rs/execpolicy-legacy/src/default.policy`
- Hook discovery: `codex-rs/hooks/src/engine/discovery.rs:38,240,283`
- Hook dispatch & matcher: `codex-rs/hooks/src/engine/dispatcher.rs:34`
- Hook schemas (wire shape): `codex-rs/hooks/src/schema.rs:71-211`
- PreToolUse parsing: `codex-rs/hooks/src/events/pre_tool_use.rs:145-228`
- PermissionRequest fold: `codex-rs/hooks/src/events/permission_request.rs:148`
- Approval events / proposed amendments: `codex-rs/protocol/src/approvals.rs:32-313`
- Granular approval config: `codex-rs/protocol/src/protocol.rs:967-1004`
- Managed config requirements (enterprise pin): `codex-rs/config/src/config_requirements.rs:629-988`
- Shell escalation helper (in-sandbox approval channel): `codex-rs/shell-escalation/src/unix/escalate_server.rs`
