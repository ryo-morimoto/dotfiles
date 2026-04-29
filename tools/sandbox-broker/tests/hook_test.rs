//! Integration tests for claude-code-hook.sh
//!
//! Fixtures match the PreToolUseHookInput contract from:
//!   @anthropic-ai/claude-agent-sdk sdk.d.ts (PreToolUseHookInput = BaseHookInput & {...})
//!
//! The hook now returns JSON stdout (SyncHookJSONOutput) with permissionDecision,
//! instead of bare exit codes.

use std::sync::Arc;
use std::time::Duration;
use tempfile::TempDir;
use tokio::io::AsyncWriteExt;

use sandbox_broker::broker::{Broker, Mode};
use sandbox_broker::policy::{
    CommandPattern, FilesystemPolicy, NetworkPolicy, Policy, WorktreePolicy,
};
use sandbox_broker::server;

fn test_policy() -> Policy {
    Policy {
        filesystem: FilesystemPolicy {
            read: vec!["./src/**".into()],
            write: vec!["./src/**".into()],
        },
        network: NetworkPolicy {
            connect: vec!["localhost:*".into()],
            bind: vec![],
        },
        commands: vec![CommandPattern {
            pattern: vec!["npm".into(), "run".into(), "*".into()],
            scope: "scripts".into(),
        }],
        worktree: WorktreePolicy {
            allow_siblings: false,
        },
    }
}

/// Build a full PreToolUseHookInput fixture matching the SDK contract.
/// All BaseHookInput fields are present to catch regressions if the hook
/// starts reading them.
fn fixture(tool_name: &str, tool_input: serde_json::Value) -> serde_json::Value {
    serde_json::json!({
        "session_id": "test-session-001",
        "transcript_path": "/tmp/test-transcript.jsonl",
        "cwd": "/tmp/test-project",
        "permission_mode": "default",
        "hook_event_name": "PreToolUse",
        "tool_name": tool_name,
        "tool_input": tool_input,
        "tool_use_id": "toolu_test_001"
    })
}

async fn start_broker_at(sandbox_dir: &std::path::Path) -> std::path::PathBuf {
    std::fs::create_dir_all(sandbox_dir).unwrap();
    let broker = Arc::new(Broker::new(test_policy(), sandbox_dir, Mode::Enforce));
    let sock = server::socket_path(sandbox_dir);

    let sock_clone = sock.clone();
    tokio::spawn(async move {
        server::serve(broker, &sock_clone).await.unwrap();
    });

    for _ in 0..50 {
        if sock.exists() {
            break;
        }
        tokio::time::sleep(Duration::from_millis(10)).await;
    }
    assert!(sock.exists(), "broker socket not created");
    sock
}

fn hook_script_path() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("adapter/claude-code-hook.sh")
}

struct HookResult {
    exit_code: i32,
    stdout: String,
    stderr: String,
}

impl HookResult {
    fn decision(&self) -> Option<String> {
        serde_json::from_str::<serde_json::Value>(&self.stdout)
            .ok()
            .and_then(|v| {
                v["hookSpecificOutput"]["permissionDecision"]
                    .as_str()
                    .map(String::from)
            })
    }

    fn reason(&self) -> Option<String> {
        serde_json::from_str::<serde_json::Value>(&self.stdout)
            .ok()
            .and_then(|v| {
                v["hookSpecificOutput"]["permissionDecisionReason"]
                    .as_str()
                    .map(String::from)
            })
    }

    fn assert_decision(&self, expected: &str) {
        assert_eq!(
            self.exit_code, 0,
            "hook exited with {}, stderr: {}",
            self.exit_code, self.stderr
        );
        let decision = self.decision().unwrap_or_else(|| {
            panic!(
                "no permissionDecision in stdout: {}",
                self.stdout
            )
        });
        assert_eq!(
            decision, expected,
            "expected decision={expected}, got={decision}, stdout: {}, stderr: {}",
            self.stdout, self.stderr
        );
    }

    fn assert_exit2_deny(&self) {
        assert_eq!(
            self.exit_code, 2,
            "expected exit 2, got {}, stderr: {}",
            self.exit_code, self.stderr
        );
    }
}

async fn run_hook(sock: &std::path::Path, input: &serde_json::Value) -> HookResult {
    let mut child = tokio::process::Command::new("bash")
        .arg(hook_script_path())
        .env("SANDBOX_BROKER_SOCK", sock.to_str().unwrap())
        .env("SANDBOX_BROKER_ENABLED", "1")
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .unwrap();

    let mut stdin = child.stdin.take().unwrap();
    stdin
        .write_all(serde_json::to_string(input).unwrap().as_bytes())
        .await
        .unwrap();
    drop(stdin);

    let output = tokio::time::timeout(Duration::from_secs(10), child.wait_with_output())
        .await
        .expect("hook timed out")
        .unwrap();

    HookResult {
        exit_code: output.status.code().unwrap_or(-1),
        stdout: String::from_utf8_lossy(&output.stdout).to_string(),
        stderr: String::from_utf8_lossy(&output.stderr).to_string(),
    }
}

async fn run_hook_with_env(
    env: Vec<(&str, &str)>,
    input: &serde_json::Value,
) -> HookResult {
    let mut cmd = tokio::process::Command::new("bash");
    cmd.arg(hook_script_path())
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped());
    for (k, v) in &env {
        cmd.env(k, v);
    }
    let mut child = cmd.spawn().unwrap();

    let mut stdin = child.stdin.take().unwrap();
    stdin
        .write_all(serde_json::to_string(input).unwrap().as_bytes())
        .await
        .unwrap();
    drop(stdin);

    let output = tokio::time::timeout(Duration::from_secs(10), child.wait_with_output())
        .await
        .expect("hook timed out")
        .unwrap();

    HookResult {
        exit_code: output.status.code().unwrap_or(-1),
        stdout: String::from_utf8_lossy(&output.stdout).to_string(),
        stderr: String::from_utf8_lossy(&output.stderr).to_string(),
    }
}

// --- Policy match tests: hook returns JSON with permissionDecision ---

#[tokio::test]
async fn hook_allows_policy_matched_read() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Read", serde_json::json!({"file_path": "./src/main.ts"}));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("allow");
}

#[tokio::test]
async fn hook_denies_policy_unmatched_read() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Read", serde_json::json!({"file_path": "./.env"}));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("ask"); // escalate → ask (human approval)
}

#[tokio::test]
async fn hook_allows_write_in_policy() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Edit", serde_json::json!({
        "file_path": "./src/lib.ts",
        "old_string": "old",
        "new_string": "new"
    }));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("allow");
}

#[tokio::test]
async fn hook_denies_write_outside_policy() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Write", serde_json::json!({
        "file_path": "./secrets/key.pem",
        "content": "secret"
    }));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("ask");
}

#[tokio::test]
async fn hook_allows_matched_command() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Bash", serde_json::json!({
        "command": "npm run build",
        "description": "Build the project"
    }));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("allow");
}

#[tokio::test]
async fn hook_denies_unmatched_command() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Bash", serde_json::json!({"command": "rm -rf /"}));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("ask");
}

// --- Passthrough tests: non-policy tools get allow ---

#[tokio::test]
async fn hook_passes_through_web_tools() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("WebFetch", serde_json::json!({
        "url": "https://example.com",
        "prompt": "get info"
    }));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("allow");
}

#[tokio::test]
async fn hook_passes_through_glob() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Glob", serde_json::json!({
        "pattern": "**/*.ts",
        "path": "/tmp"
    }));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("allow");
}

#[tokio::test]
async fn hook_passes_through_mcp_tools() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("mcp__memory__create_entities", serde_json::json!({"entities": []}));
    let r = run_hook(&sock, &input).await;
    r.assert_decision("allow");
}

// --- Error handling tests ---

#[tokio::test]
async fn hook_disabled_passes_through() {
    let input = fixture("Read", serde_json::json!({"file_path": "./.env"}));
    let r = run_hook_with_env(
        vec![("SANDBOX_BROKER_ENABLED", "0")],
        &input,
    )
    .await;
    assert_eq!(r.exit_code, 0);
}

#[tokio::test]
async fn hook_no_socket_denies_via_exit2() {
    let input = fixture("Read", serde_json::json!({"file_path": "./src/main.ts"}));
    let r = run_hook_with_env(
        vec![
            ("SANDBOX_BROKER_SOCK", "/nonexistent/broker.sock"),
            ("SANDBOX_BROKER_ENABLED", "1"),
        ],
        &input,
    )
    .await;
    r.assert_exit2_deny();
    assert!(r.stderr.contains("no socket"), "stderr: {}", r.stderr);
}

// --- JSON output structure validation ---

#[tokio::test]
async fn hook_output_matches_sync_hook_json_output_schema() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Read", serde_json::json!({"file_path": "./src/main.ts"}));
    let r = run_hook(&sock, &input).await;

    let output: serde_json::Value = serde_json::from_str(&r.stdout)
        .unwrap_or_else(|e| panic!("invalid JSON stdout: {e}, raw: {}", r.stdout));

    // SyncHookJSONOutput must have hookSpecificOutput
    assert!(
        output.get("hookSpecificOutput").is_some(),
        "missing hookSpecificOutput in: {output}"
    );

    let specific = &output["hookSpecificOutput"];

    // PreToolUseHookSpecificOutput must have hookEventName
    assert_eq!(specific["hookEventName"], "PreToolUse");

    // permissionDecision must be one of the valid values
    let decision = specific["permissionDecision"].as_str().unwrap();
    assert!(
        ["allow", "deny", "ask", "defer"].contains(&decision),
        "invalid permissionDecision: {decision}"
    );
}

#[tokio::test]
async fn hook_deny_output_includes_reason() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = fixture("Read", serde_json::json!({"file_path": "./.env"}));
    let r = run_hook(&sock, &input).await;

    let reason = r.reason().expect("missing permissionDecisionReason");
    assert!(
        reason.starts_with("sandbox-broker:"),
        "reason should be prefixed: {reason}"
    );
}

// --- Full fixture with optional fields ---

#[tokio::test]
async fn hook_handles_subagent_fields() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;

    let input = serde_json::json!({
        "session_id": "test-session-002",
        "transcript_path": "/tmp/transcript.jsonl",
        "cwd": "/tmp/project",
        "permission_mode": "auto",
        "hook_event_name": "PreToolUse",
        "tool_name": "Read",
        "tool_input": {"file_path": "./src/main.ts"},
        "tool_use_id": "toolu_subagent_001",
        "agent_id": "agent-abc",
        "agent_type": "code-reviewer"
    });

    let r = run_hook(&sock, &input).await;
    r.assert_decision("allow");
}
