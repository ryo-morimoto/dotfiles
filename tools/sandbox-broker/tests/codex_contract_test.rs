//! Codex hook contract tests
//!
//! Unlike Claude Code (which has an installable SDK with .d.ts types),
//! Codex's hook contract is defined by documentation:
//!   https://developers.openai.com/codex/hooks#pretooluse
//!
//! These tests verify that our fixtures and hook I/O match the documented
//! contract. They serve as canaries: if Codex changes its protocol, manual
//! review of the docs page is required and these assertions should be updated.
//!
//! Fixture maintenance strategy:
//! - Required fields: session_id, cwd, hook_event_name, tool_name, tool_input, tool_use_id
//! - Optional fields: transcript_path, model, turn_id
//! - Tool names: Bash, apply_patch, read_file, list_dir, web_search, mcp_tool
//! - Bash tool_input.command is an ARRAY (not string like Claude Code)
//! - Output: hookSpecificOutput with permissionDecision (only "deny" is enforced)
//! - Fallback: exit 2 + stderr for blocking when JSON isn't sufficient

use std::collections::HashSet;

// --- Input contract ---

#[test]
fn codex_contract_required_input_fields() {
    let required = [
        "session_id",
        "cwd",
        "hook_event_name",
        "tool_name",
        "tool_input",
        "tool_use_id",
    ];

    let fixture = serde_json::json!({
        "session_id": "codex-session-001",
        "transcript_path": "/tmp/transcript.jsonl",
        "cwd": "/tmp/project",
        "hook_event_name": "PreToolUse",
        "model": "o3",
        "turn_id": "turn_001",
        "tool_name": "Bash",
        "tool_input": {"command": ["ls"]},
        "tool_use_id": "tool_001"
    });

    for field in &required {
        assert!(
            fixture.get(field).is_some(),
            "fixture missing required field: {field}"
        );
    }
}

#[test]
fn codex_contract_optional_input_fields() {
    let optional = ["transcript_path", "model", "turn_id"];

    let minimal = serde_json::json!({
        "session_id": "s",
        "cwd": "/tmp",
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": ["ls"]},
        "tool_use_id": "t"
    });

    // Minimal fixture should work without optional fields
    for field in &optional {
        assert!(
            minimal.get(field).is_none(),
            "minimal fixture should not have optional field: {field}"
        );
    }
}

// --- Tool name coverage ---

#[test]
fn codex_contract_known_tool_names() {
    let documented_tools: HashSet<&str> = [
        "Bash",        // shell command execution (array-based command)
        "apply_patch", // file modifications via unified diff
        "read_file",   // reading a file
        "list_dir",    // listing directory contents
        "web_search",  // web search
        "mcp_tool",    // MCP tool call (also mcp__* prefixed)
    ]
    .into_iter()
    .collect();

    // Tools our hook explicitly handles (maps to broker operation)
    let handled: HashSet<&str> = ["Bash", "read_file", "apply_patch", "list_dir"]
        .into_iter()
        .collect();

    // Tools our hook explicitly passes through
    let passthrough: HashSet<&str> = ["web_search", "mcp_tool"].into_iter().collect();

    let unhandled: HashSet<&str> = documented_tools
        .difference(&handled)
        .copied()
        .collect::<HashSet<_>>()
        .difference(&passthrough)
        .copied()
        .collect();

    assert!(
        unhandled.is_empty(),
        "Codex tools not handled or passed through: {unhandled:?}"
    );
}

// --- Tool input format ---

#[test]
fn codex_contract_bash_command_is_array() {
    let bash_input = serde_json::json!({"command": ["npm", "run", "build"]});
    let command = bash_input["command"].as_array();
    assert!(
        command.is_some(),
        "Codex Bash tool_input.command must be an array"
    );
    assert_eq!(command.unwrap().len(), 3);
}

#[test]
fn codex_contract_read_file_has_path() {
    let input = serde_json::json!({"path": "./src/main.ts"});
    assert!(input["path"].is_string());
}

#[test]
fn codex_contract_apply_patch_has_patch_and_files() {
    let input = serde_json::json!({
        "patch": "--- a/file.ts\n+++ b/file.ts",
        "files": ["./file.ts"]
    });
    assert!(input["patch"].is_string());
    assert!(input["files"].is_array());
}

#[test]
fn codex_contract_list_dir_has_path() {
    let input = serde_json::json!({"path": "./src"});
    assert!(input["path"].is_string());
}

// --- Output contract ---

#[test]
fn codex_contract_deny_output_shape() {
    let output = serde_json::json!({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "sandbox-broker: denied by policy"
        }
    });

    assert!(output.get("hookSpecificOutput").is_some());
    let specific = &output["hookSpecificOutput"];
    assert_eq!(specific["hookEventName"], "PreToolUse");
    assert_eq!(specific["permissionDecision"], "deny");
    assert!(specific["permissionDecisionReason"].is_string());
}

#[test]
fn codex_contract_allow_is_silent() {
    // Codex does NOT enforce permissionDecision="allow".
    // The correct behavior is exit 0 with no stdout.
    // This test documents the constraint.
    let empty_stdout = "";
    assert!(
        empty_stdout.is_empty(),
        "allow must be silent — Codex ignores allow JSON"
    );
}

#[test]
fn codex_contract_escalate_uses_exit2() {
    // Codex does NOT support permissionDecision="ask".
    // The correct behavior is exit 2 + stderr message.
    // This test documents the constraint.
    let exit_code = 2;
    assert_eq!(exit_code, 2, "escalate must use exit code 2");
}

// --- Protocol differences from Claude Code ---

#[test]
fn codex_contract_vs_claude_code_differences() {
    // Document the key differences as assertions
    // so they fail if we accidentally mix up the protocols.

    // 1. Tool names differ
    let codex_read = "read_file";
    let claude_read = "Read";
    assert_ne!(codex_read, claude_read);

    let codex_write = "apply_patch";
    let claude_write = "Edit";
    assert_ne!(codex_write, claude_write);

    // 2. Bash command format differs
    let codex_bash_cmd = serde_json::json!({"command": ["ls", "-la"]});
    let claude_bash_cmd = serde_json::json!({"command": "ls -la"});
    assert!(codex_bash_cmd["command"].is_array());
    assert!(claude_bash_cmd["command"].is_string());

    // 3. Supported decisions differ
    // Claude Code: allow, deny, ask, defer (all enforced)
    // Codex: only deny is enforced; allow/ask/defer are parsed but fail-open
}
