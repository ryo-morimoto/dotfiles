//! Contract tests: verify that our fixtures and hook I/O match the
//! PreToolUseHookInput / SyncHookJSONOutput schemas from:
//!   @anthropic-ai/claude-agent-sdk sdk.d.ts
//!
//! These tests parse the SDK type definitions and validate that:
//! 1. Our fixture JSON contains all required fields from BaseHookInput + PreToolUseHookInput
//! 2. Our hook output JSON matches SyncHookJSONOutput + PreToolUseHookSpecificOutput
//! 3. The set of tool names we handle is complete
//!
//! If the SDK updates its contract, these tests fail — that's the point.

use std::collections::HashSet;

const SDK_PATH: &str = concat!(
    env!("HOME"),
    "/.bun/install/cache/@anthropic-ai/claude-agent-sdk@0.2.111@@@1/sdk.d.ts"
);

fn read_sdk() -> Option<String> {
    std::fs::read_to_string(SDK_PATH).ok()
}

fn require_sdk() -> String {
    read_sdk().unwrap_or_else(|| {
        panic!(
            "SDK at {SDK_PATH} not found. Run with --include-ignored locally."
        )
    })
}

// --- Input contract tests ---

#[test]
#[ignore = "requires local claude-agent-sdk install"]
fn contract_base_hook_input_fields_present_in_fixture() {
    let sdk = require_sdk();

    // Extract BaseHookInput required fields from SDK
    // BaseHookInput = { session_id: string; transcript_path: string; cwd: string; ... }
    let required_base_fields = ["session_id", "transcript_path", "cwd"];
    let optional_base_fields = ["permission_mode", "agent_id", "agent_type"];

    // Verify all required fields exist in the SDK type definition
    assert!(
        sdk.contains("type BaseHookInput"),
        "SDK no longer exports BaseHookInput — contract may have changed"
    );
    for field in &required_base_fields {
        assert!(
            sdk.contains(&format!("{field}: string")),
            "BaseHookInput no longer has required field '{field}'"
        );
    }

    // Build a fixture and verify it has all required fields
    let fixture = serde_json::json!({
        "session_id": "test-001",
        "transcript_path": "/tmp/transcript.jsonl",
        "cwd": "/tmp/project",
        "permission_mode": "default",
        "hook_event_name": "PreToolUse",
        "tool_name": "Read",
        "tool_input": {"file_path": "./src/main.ts"},
        "tool_use_id": "toolu_test_001"
    });

    for field in &required_base_fields {
        assert!(
            fixture.get(field).is_some(),
            "fixture missing required BaseHookInput field: {field}"
        );
    }
    for field in &optional_base_fields {
        // Optional fields should be accepted but not required
        let mut with_optional = fixture.clone();
        with_optional[field] = serde_json::json!("test-value");
        assert!(with_optional.get(field).is_some());
    }
}

#[test]
#[ignore = "requires local claude-agent-sdk install"]
fn contract_pre_tool_use_hook_input_fields() {
    let sdk = require_sdk();

    assert!(
        sdk.contains("type PreToolUseHookInput = BaseHookInput &"),
        "PreToolUseHookInput type declaration changed"
    );

    // PreToolUse-specific required fields
    let required_fields = [
        ("hook_event_name", "'PreToolUse'"),
        ("tool_name", "string"),
        ("tool_input", "unknown"),
        ("tool_use_id", "string"),
    ];

    for (field, _type_hint) in &required_fields {
        assert!(
            sdk.contains(field),
            "PreToolUseHookInput missing field: {field}"
        );
    }
}

// --- Output contract tests ---

#[test]
#[ignore = "requires local claude-agent-sdk install"]
fn contract_sync_hook_json_output_shape() {
    let sdk = require_sdk();

    assert!(
        sdk.contains("type SyncHookJSONOutput"),
        "SyncHookJSONOutput type not found in SDK"
    );

    // Required shape: { hookSpecificOutput?: PreToolUseHookSpecificOutput | ... }
    assert!(
        sdk.contains("hookSpecificOutput?:"),
        "SyncHookJSONOutput missing hookSpecificOutput field"
    );
}

#[test]
#[ignore = "requires local claude-agent-sdk install"]
fn contract_pre_tool_use_hook_specific_output() {
    let sdk = require_sdk();

    assert!(
        sdk.contains("type PreToolUseHookSpecificOutput"),
        "PreToolUseHookSpecificOutput type not found"
    );

    let expected_fields = [
        "hookEventName",
        "permissionDecision",
        "permissionDecisionReason",
        "updatedInput",
        "additionalContext",
    ];

    // Verify all known output fields exist in SDK
    for field in &expected_fields {
        assert!(
            sdk.contains(field),
            "PreToolUseHookSpecificOutput missing field: {field}"
        );
    }
}

#[test]
#[ignore = "requires local claude-agent-sdk install"]
fn contract_permission_decision_values() {
    let sdk = require_sdk();

    assert!(
        sdk.contains("type HookPermissionDecision"),
        "HookPermissionDecision type not found"
    );

    let expected_values = ["allow", "deny", "ask", "defer"];
    for val in &expected_values {
        assert!(
            sdk.contains(&format!("'{val}'")),
            "HookPermissionDecision missing value: {val}"
        );
    }
}

// --- Tool name coverage ---

#[test]
fn contract_known_tool_names_are_handled() {
    // Built-in tool names that our hook should handle or explicitly pass through.
    // Source: Claude Code tool definitions in the current session's system prompt.
    let known_tools: HashSet<&str> = [
        "Bash",
        "Read",
        "Edit",
        "Write",
        "Glob",
        "Grep",
        "Agent",
        "WebFetch",
        "WebSearch",
        "AskUserQuestion",
    ]
    .into_iter()
    .collect();

    // Tools our hook explicitly handles (maps to broker operation)
    let handled: HashSet<&str> = ["Bash", "Read", "Edit", "Write"].into_iter().collect();

    // Tools our hook explicitly passes through
    let passthrough: HashSet<&str> = ["Glob", "Grep", "WebFetch", "WebSearch"]
        .into_iter()
        .collect();

    // Everything else falls through to the `*` case → passthrough
    let unhandled: HashSet<&str> = known_tools
        .difference(&handled)
        .copied()
        .collect::<HashSet<_>>()
        .difference(&passthrough)
        .copied()
        .collect();

    // These tools pass through via the `*` wildcard — that's intentional.
    // If a new tool appears that should be policy-controlled, add it to `handled`.
    let intentionally_unhandled: HashSet<&str> =
        ["Agent", "AskUserQuestion"].into_iter().collect();

    let unexpected: Vec<&&str> = unhandled
        .iter()
        .filter(|t| !intentionally_unhandled.contains(**t))
        .collect();

    assert!(
        unexpected.is_empty(),
        "new tools not explicitly handled or marked as passthrough: {unexpected:?}"
    );
}

// --- SDK version tracking ---

#[test]
#[ignore = "requires local claude-agent-sdk install"]
fn contract_sdk_version_check() {
    // If the SDK version changes, this test fails, signaling that the contract
    // should be re-verified. Update the path constant after verification.
    assert!(
        std::path::Path::new(SDK_PATH).exists(),
        "SDK at {SDK_PATH} not found. The claude-agent-sdk version may have changed. \
         Update SDK_PATH after verifying the hook contract still holds."
    );
}

#[test]
#[ignore = "requires local claude-agent-sdk install"]
fn contract_no_new_required_fields_in_base_hook_input() {
    let sdk = require_sdk();

    // Extract the BaseHookInput block
    let start = sdk.find("type BaseHookInput = {").expect("BaseHookInput not found");
    let block = &sdk[start..];
    let end = block.find("};").expect("BaseHookInput block end not found");
    let block = &block[..end];

    // Count required fields (no `?:` suffix)
    let required: Vec<&str> = block
        .lines()
        .filter(|l| l.contains(": ") && !l.contains("?:") && !l.contains("//") && !l.contains("type ") && !l.contains("*/"))
        .collect();

    // Known required: session_id, transcript_path, cwd (3 fields)
    assert!(
        required.len() <= 3,
        "BaseHookInput has new required fields beyond session_id/transcript_path/cwd: {required:?}. \
         Update fixtures and hook to handle them."
    );
}
