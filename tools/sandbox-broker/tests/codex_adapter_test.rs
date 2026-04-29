//! Integration tests for codex-hook.sh
//!
//! Fixtures match the Codex PreToolUseHookInput contract from:
//!   https://developers.openai.com/codex/hooks#pretooluse
//!
//! Key differences from Claude Code:
//! - tool_name: Bash (same), apply_patch, read_file, list_dir, web_search, mcp_tool
//! - Bash tool_input.command is an array, not a string
//! - permissionDecision "allow" is NOT enforced → hook uses silent exit 0
//! - permissionDecision "ask" is NOT supported → hook uses exit 2 + stderr
//! - Output: hookSpecificOutput JSON (same envelope as Claude Code)

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

/// Build a full Codex PreToolUseHookInput fixture.
/// Fields match https://developers.openai.com/codex/hooks#pretooluse
fn codex_fixture(tool_name: &str, tool_input: serde_json::Value) -> serde_json::Value {
    serde_json::json!({
        "session_id": "codex-test-session-001",
        "transcript_path": "/tmp/codex-transcript.jsonl",
        "cwd": "/tmp/test-project",
        "hook_event_name": "PreToolUse",
        "model": "o3",
        "turn_id": "turn_001",
        "tool_name": tool_name,
        "tool_input": tool_input,
        "tool_use_id": "tool_codex_001"
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

fn codex_hook_script_path() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("adapter/codex-hook.sh")
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

    fn assert_silent_allow(&self) {
        assert_eq!(
            self.exit_code, 0,
            "expected exit 0, got {}, stderr: {}",
            self.exit_code, self.stderr
        );
        assert!(
            self.stdout.trim().is_empty() || self.decision().is_none(),
            "allow should be silent (no hookSpecificOutput), stdout: {}",
            self.stdout
        );
    }

    fn assert_deny(&self) {
        assert_eq!(
            self.exit_code, 0,
            "deny should exit 0, got {}, stderr: {}",
            self.exit_code, self.stderr
        );
        let decision = self.decision().unwrap_or_else(|| {
            panic!("no permissionDecision in stdout: {}", self.stdout)
        });
        assert_eq!(
            decision, "deny",
            "expected deny, got={decision}, stdout: {}",
            self.stdout
        );
    }

    fn assert_escalate_exit2(&self) {
        assert_eq!(
            self.exit_code, 2,
            "escalate should exit 2, got {}, stderr: {}",
            self.exit_code, self.stderr
        );
        assert!(
            self.stderr.contains("sandbox-broker:"),
            "stderr should contain broker prefix: {}",
            self.stderr
        );
    }
}

async fn run_codex_hook(sock: &std::path::Path, input: &serde_json::Value) -> HookResult {
    let mut child = tokio::process::Command::new("bash")
        .arg(codex_hook_script_path())
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

async fn run_codex_hook_with_env(
    env: Vec<(&str, &str)>,
    input: &serde_json::Value,
) -> HookResult {
    let mut cmd = tokio::process::Command::new("bash");
    cmd.arg(codex_hook_script_path())
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped());
    for (k, v) in &env {
        cmd.env(k, v);
    }
    let mut child = cmd.spawn().unwrap();

    let mut stdin = child.stdin.take().unwrap();
    // Ignore broken pipe — script may exit before reading stdin (e.g. ENABLED=0)
    let _ = stdin
        .write_all(serde_json::to_string(input).unwrap().as_bytes())
        .await;
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

// --- Codex-specific tool_name mapping tests ---

#[tokio::test]
async fn codex_allows_policy_matched_bash() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    // Codex Bash: command is an array
    let input = codex_fixture("Bash", serde_json::json!({"command": ["npm", "run", "build"]}));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_silent_allow();
}

#[tokio::test]
async fn codex_denies_unmatched_bash() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("Bash", serde_json::json!({"command": ["rm", "-rf", "/"]}));
    let r = run_codex_hook(&sock, &input).await;
    // Unmatched command → escalate → exit 2
    r.assert_escalate_exit2();
}

#[tokio::test]
async fn codex_allows_policy_matched_read_file() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("read_file", serde_json::json!({"path": "./src/main.ts"}));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_silent_allow();
}

#[tokio::test]
async fn codex_escalates_unmatched_read_file() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("read_file", serde_json::json!({"path": "./.env"}));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_escalate_exit2();
}

#[tokio::test]
async fn codex_allows_policy_matched_apply_patch() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("apply_patch", serde_json::json!({
        "patch": "--- a/src/lib.ts\n+++ b/src/lib.ts\n@@ -1 +1 @@\n-old\n+new",
        "files": ["./src/lib.ts"]
    }));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_silent_allow();
}

#[tokio::test]
async fn codex_escalates_unmatched_apply_patch() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("apply_patch", serde_json::json!({
        "patch": "--- a/secrets/key.pem\n+++ b/secrets/key.pem",
        "files": ["./secrets/key.pem"]
    }));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_escalate_exit2();
}

#[tokio::test]
async fn codex_allows_policy_matched_list_dir() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("list_dir", serde_json::json!({"path": "./src/components"}));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_silent_allow();
}

// --- Passthrough tests ---

#[tokio::test]
async fn codex_passes_through_web_search() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("web_search", serde_json::json!({"query": "rust async"}));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_silent_allow();
}

#[tokio::test]
async fn codex_passes_through_mcp_tools() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("mcp__memory__create_entities", serde_json::json!({"entities": []}));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_silent_allow();
}

#[tokio::test]
async fn codex_passes_through_unknown_tools() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("some_future_tool", serde_json::json!({"data": 42}));
    let r = run_codex_hook(&sock, &input).await;
    r.assert_silent_allow();
}

// --- Error handling ---

#[tokio::test]
async fn codex_disabled_passes_through() {
    let input = codex_fixture("read_file", serde_json::json!({"path": "./.env"}));
    let r = run_codex_hook_with_env(
        vec![("SANDBOX_BROKER_ENABLED", "0")],
        &input,
    )
    .await;
    assert_eq!(r.exit_code, 0);
}

#[tokio::test]
async fn codex_no_socket_passes_through() {
    let input = codex_fixture("read_file", serde_json::json!({"path": "./src/main.ts"}));
    let r = run_codex_hook_with_env(
        vec![
            ("SANDBOX_BROKER_SOCK", "/nonexistent/broker.sock"),
            ("SANDBOX_BROKER_ENABLED", "1"),
        ],
        &input,
    )
    .await;
    assert_eq!(r.exit_code, 0, "no socket should passthrough, stderr: {}", r.stderr);
}

#[tokio::test]
async fn codex_broker_unreachable_passes_through() {
    let tmp = TempDir::new().unwrap();
    let sock_path = tmp.path().join("broker.sock");
    {
        let _l = std::os::unix::net::UnixListener::bind(&sock_path).unwrap();
    }
    assert!(sock_path.exists(), "socket file should remain after drop");

    let input = codex_fixture("read_file", serde_json::json!({"path": "./src/main.ts"}));
    let r = run_codex_hook_with_env(
        vec![
            ("SANDBOX_BROKER_SOCK", sock_path.to_str().unwrap()),
            ("SANDBOX_BROKER_ENABLED", "1"),
        ],
        &input,
    )
    .await;
    assert_eq!(
        r.exit_code, 0,
        "unreachable broker should passthrough, stderr: {}",
        r.stderr
    );
}

// --- Deny output structure validation ---

#[tokio::test]
async fn codex_deny_output_has_correct_json_structure() {
    let tmp = TempDir::new().unwrap();
    let sandbox_dir = tmp.path().join(".sandbox");
    std::fs::create_dir_all(&sandbox_dir).unwrap();
    // Empty policy = deny everything
    let broker = Arc::new(Broker::new(Policy::default(), &sandbox_dir, Mode::Enforce));
    let sock = server::socket_path(&sandbox_dir);
    let sock_clone = sock.clone();
    tokio::spawn(async move {
        server::serve(broker, &sock_clone).await.unwrap();
    });
    for _ in 0..50 {
        if sock.exists() { break; }
        tokio::time::sleep(Duration::from_millis(10)).await;
    }

    let input = codex_fixture("Bash", serde_json::json!({"command": ["echo", "hello"]}));
    let r = run_codex_hook(&sock, &input).await;

    // With empty policy, command is unmatched → escalate → exit 2
    assert_eq!(r.exit_code, 2);
}

// --- Fixture contract compliance ---

#[tokio::test]
async fn codex_fixture_has_all_required_fields() {
    let fixture = codex_fixture("Bash", serde_json::json!({"command": ["ls"]}));

    let required = ["session_id", "cwd", "hook_event_name", "tool_name", "tool_input", "tool_use_id"];
    for field in &required {
        assert!(
            fixture.get(field).is_some(),
            "fixture missing required field: {field}"
        );
    }

    assert_eq!(fixture["hook_event_name"], "PreToolUse");
}

#[tokio::test]
async fn codex_fixture_has_optional_fields() {
    let fixture = codex_fixture("Bash", serde_json::json!({"command": ["ls"]}));

    let optional = ["transcript_path", "model", "turn_id"];
    for field in &optional {
        assert!(
            fixture.get(field).is_some(),
            "fixture should include optional field for completeness: {field}"
        );
    }
}

// --- Apply patch with patch-only input (no files array) ---

#[tokio::test]
async fn codex_apply_patch_extracts_path_from_diff() {
    let tmp = TempDir::new().unwrap();
    let sock = start_broker_at(&tmp.path().join(".sandbox")).await;
    let input = codex_fixture("apply_patch", serde_json::json!({
        "patch": "--- a/src/utils.ts\n+++ b/src/utils.ts\n@@ -1 +1 @@\n-old\n+new"
    }));
    let r = run_codex_hook(&sock, &input).await;
    // src/utils.ts matches ./src/** write policy
    r.assert_silent_allow();
}
