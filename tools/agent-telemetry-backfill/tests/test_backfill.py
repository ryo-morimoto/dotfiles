import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "backfill.py"
SPEC = importlib.util.spec_from_file_location("agent_telemetry_backfill", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
BACKFILL = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = BACKFILL
SPEC.loader.exec_module(BACKFILL)


def write_jsonl(path: Path, items: list[dict]) -> None:
    path.write_text("".join(json.dumps(item) + "\n" for item in items), encoding="utf-8")


def attrs(record: dict) -> dict:
    values = {}
    for attribute in record["attributes"]:
        value = next(iter(attribute["value"].values()))
        if attribute["key"] in {"turn.duration_ms", "llm.ttft_ms", "tool.call.count"}:
            value = int(value)
        values[attribute["key"]] = value
    return values


class BackfillTest(unittest.TestCase):
    def test_claude_extracts_metadata_without_content(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "claude.jsonl"
            write_jsonl(
                path,
                [
                    {
                        "type": "user",
                        "timestamp": "2026-08-01T00:00:00Z",
                        "promptId": "prompt-1",
                        "sessionId": "session-1",
                        "message": {"content": "private prompt"},
                    },
                    {
                        "type": "assistant",
                        "timestamp": "2026-08-01T00:00:01Z",
                        "message": {
                            "model": "claude-test",
                            "content": [
                                {
                                    "type": "tool_use",
                                    "id": "tool-1",
                                    "name": "Read",
                                    "input": {"file_path": "/private/path"},
                                }
                            ],
                        },
                    },
                    {
                        "type": "user",
                        "timestamp": "2026-08-01T00:00:02Z",
                        "message": {
                            "content": [
                                {
                                    "type": "tool_result",
                                    "tool_use_id": "tool-1",
                                    "content": "private result",
                                }
                            ]
                        },
                    },
                    {
                        "type": "system",
                        "subtype": "turn_duration",
                        "durationMs": 2000,
                        "timestamp": "2026-08-01T00:00:02Z",
                    },
                ],
            )
            stats = BACKFILL.ParseStats()
            records = BACKFILL.parse_claude(path, stats)

        self.assertEqual(len(records), 2)
        turn = attrs(next(record for record in records if record["body"]["stringValue"] == "agent.turn"))
        self.assertEqual(turn["turn.duration_ms"], 2000)
        self.assertEqual(turn["tool.call.count"], 1)
        self.assertNotIn("private prompt", json.dumps(records))
        self.assertNotIn("private result", json.dumps(records))
        self.assertNotIn("/private/path", json.dumps(records))

    def test_codex_extracts_turn_duration_and_ttft(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "codex.jsonl"
            write_jsonl(
                path,
                [
                    {
                        "type": "session_meta",
                        "timestamp": "2026-08-01T00:00:00Z",
                        "payload": {"session_id": "session-2"},
                    },
                    {
                        "type": "event_msg",
                        "timestamp": "2026-08-01T00:00:01Z",
                        "payload": {"type": "task_started", "turn_id": "turn-2"},
                    },
                    {
                        "type": "turn_context",
                        "timestamp": "2026-08-01T00:00:01Z",
                        "payload": {"turn_id": "turn-2", "model": "codex-test"},
                    },
                    {
                        "type": "response_item",
                        "timestamp": "2026-08-01T00:00:02Z",
                        "payload": {
                            "type": "custom_tool_call",
                            "call_id": "call-2",
                            "name": "exec_command",
                            "input": "private command",
                        },
                    },
                    {
                        "type": "response_item",
                        "timestamp": "2026-08-01T00:00:03Z",
                        "payload": {
                            "type": "custom_tool_call_output",
                            "call_id": "call-2",
                            "output": "private output",
                        },
                    },
                    {
                        "type": "event_msg",
                        "timestamp": "2026-08-01T00:00:04Z",
                        "payload": {
                            "type": "task_complete",
                            "turn_id": "turn-2",
                            "duration_ms": 3000,
                            "time_to_first_token_ms": 800,
                            "last_agent_message": "private response",
                        },
                    },
                ],
            )
            stats = BACKFILL.ParseStats()
            records = BACKFILL.parse_codex(path, stats)

        turn = attrs(next(record for record in records if record["body"]["stringValue"] == "agent.turn"))
        self.assertEqual(turn["turn.duration_ms"], 3000)
        self.assertEqual(turn["llm.ttft_ms"], 800)
        self.assertEqual(turn["model.name"], "codex-test")
        serialized = json.dumps(records)
        self.assertNotIn("private command", serialized)
        self.assertNotIn("private output", serialized)
        self.assertNotIn("private response", serialized)


if __name__ == "__main__":
    unittest.main()
