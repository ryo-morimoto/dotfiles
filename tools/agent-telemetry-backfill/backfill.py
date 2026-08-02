#!/usr/bin/env python3
"""Emit privacy-minimized Claude Code and Codex transcript summaries as OTLP logs."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


SERVICE_NAME = "agent-telemetry-backfill"
SCOPE_NAME = "dotfiles.agent-telemetry-backfill"


@dataclass
class ParseStats:
    files: int = 0
    lines: int = 0
    skipped_lines: int = 0
    turns: int = 0
    tools: int = 0


@dataclass
class Turn:
    agent: str
    turn_id: str
    conversation_id: str
    timestamp_ns: int
    model: str | None = None
    tool_calls: int = 0
    tool_failures: int = 0
    duration_ms: int | None = None
    ttft_ms: int | None = None
    tool_names: dict[str, str] = field(default_factory=dict)


def parse_timestamp_ns(value: Any) -> int | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return int(parsed.timestamp() * 1_000_000_000)


def stable_event_id(*parts: str) -> str:
    return hashlib.sha256("\0".join(parts).encode()).hexdigest()


def otlp_value(value: str | int | float | bool) -> dict[str, Any]:
    if isinstance(value, bool):
        return {"boolValue": value}
    if isinstance(value, int):
        return {"intValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    return {"stringValue": value}


def attributes(values: dict[str, str | int | float | bool | None]) -> list[dict[str, Any]]:
    return [
        {"key": key, "value": otlp_value(value)}
        for key, value in sorted(values.items())
        if value is not None
    ]


def log_record(
    *,
    timestamp_ns: int,
    body: str,
    values: dict[str, str | int | float | bool | None],
) -> dict[str, Any]:
    return {
        "timeUnixNano": str(timestamp_ns),
        "observedTimeUnixNano": str(timestamp_ns),
        "severityNumber": 9,
        "severityText": "INFO",
        "body": {"stringValue": body},
        "attributes": attributes(values),
    }


def turn_record(turn: Turn, source: Path) -> dict[str, Any]:
    values: dict[str, str | int | bool | None] = {
        "event.name": "agent.turn",
        "event.id": stable_event_id(str(source), turn.turn_id, "turn"),
        "agent.name": turn.agent,
        "telemetry.source": "backfill",
        "turn.id": turn.turn_id,
        "conversation.id": turn.conversation_id,
        "model.name": turn.model,
        "turn.duration_ms": turn.duration_ms,
        "llm.ttft_ms": turn.ttft_ms,
        "tool.call.count": turn.tool_calls,
        "tool.failure.count": turn.tool_failures,
    }
    return log_record(timestamp_ns=turn.timestamp_ns, body="agent.turn", values=values)


def tool_record(
    *,
    source: Path,
    turn: Turn,
    call_id: str,
    name: str,
    timestamp_ns: int,
    success: bool | None,
) -> dict[str, Any]:
    values: dict[str, str | bool | None] = {
        "event.name": "agent.tool",
        "event.id": stable_event_id(str(source), turn.turn_id, "tool", call_id),
        "agent.name": turn.agent,
        "telemetry.source": "backfill",
        "turn.id": turn.turn_id,
        "conversation.id": turn.conversation_id,
        "tool.call.id": call_id,
        "tool.name": name,
        "tool.success": success,
    }
    return log_record(timestamp_ns=timestamp_ns, body="agent.tool", values=values)


def read_json_lines(path: Path, stats: ParseStats) -> Iterable[dict[str, Any]]:
    stats.files += 1
    try:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                stats.lines += 1
                try:
                    item = json.loads(line)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    stats.skipped_lines += 1
                    continue
                if isinstance(item, dict):
                    yield item
                else:
                    stats.skipped_lines += 1
    except OSError:
        stats.skipped_lines += 1


def message_blocks(item: dict[str, Any]) -> list[dict[str, Any]]:
    message = item.get("message")
    if not isinstance(message, dict):
        return []
    content = message.get("content")
    if not isinstance(content, list):
        return []
    return [block for block in content if isinstance(block, dict)]


def is_claude_prompt(item: dict[str, Any]) -> bool:
    if item.get("type") != "user" or item.get("isMeta") is True:
        return False
    blocks = message_blocks(item)
    if blocks:
        return any(block.get("type") != "tool_result" for block in blocks)
    message = item.get("message")
    return isinstance(message, dict) and isinstance(message.get("content"), str)


def parse_claude(path: Path, stats: ParseStats) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    current: Turn | None = None

    for item in read_json_lines(path, stats):
        timestamp_ns = parse_timestamp_ns(item.get("timestamp"))
        if timestamp_ns is None:
            continue

        if is_claude_prompt(item):
            turn_id = str(item.get("promptId") or item.get("uuid") or "")
            conversation_id = str(item.get("sessionId") or item.get("session_id") or "")
            if turn_id and conversation_id:
                current = Turn(
                    agent="claude_code",
                    turn_id=turn_id,
                    conversation_id=conversation_id,
                    timestamp_ns=timestamp_ns,
                )
            continue

        if current is None:
            continue

        if item.get("type") == "assistant":
            message = item.get("message")
            if isinstance(message, dict) and isinstance(message.get("model"), str):
                current.model = message["model"]
            for block in message_blocks(item):
                if block.get("type") != "tool_use":
                    continue
                call_id = str(block.get("id") or "")
                name = str(block.get("name") or "unknown")
                if call_id:
                    current.tool_names[call_id] = name
                    current.tool_calls += 1
            continue

        if item.get("type") == "user":
            for block in message_blocks(item):
                if block.get("type") != "tool_result":
                    continue
                call_id = str(block.get("tool_use_id") or "")
                if not call_id:
                    continue
                success = not bool(block.get("is_error", False))
                if not success:
                    current.tool_failures += 1
                records.append(
                    tool_record(
                        source=path,
                        turn=current,
                        call_id=call_id,
                        name=current.tool_names.get(call_id, "unknown"),
                        timestamp_ns=timestamp_ns,
                        success=success,
                    )
                )
                stats.tools += 1
            continue

        if item.get("type") == "system" and item.get("subtype") == "turn_duration":
            duration_ms = item.get("durationMs")
            if isinstance(duration_ms, int):
                current.duration_ms = duration_ms
            current.timestamp_ns = timestamp_ns
            records.append(turn_record(current, path))
            stats.turns += 1
            current = None

    return records


def explicit_tool_success(output: Any) -> bool | None:
    if not isinstance(output, str) or not output:
        return None
    try:
        value = json.loads(output)
    except json.JSONDecodeError:
        return None
    if not isinstance(value, dict):
        return None
    if isinstance(value.get("success"), bool):
        return value["success"]
    if isinstance(value.get("is_error"), bool):
        return not value["is_error"]
    if isinstance(value.get("isError"), bool):
        return not value["isError"]
    return None


def parse_codex(path: Path, stats: ParseStats) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    conversation_id = ""
    current: Turn | None = None

    for item in read_json_lines(path, stats):
        timestamp_ns = parse_timestamp_ns(item.get("timestamp"))
        payload = item.get("payload")
        if timestamp_ns is None or not isinstance(payload, dict):
            continue

        if item.get("type") == "session_meta":
            conversation_id = str(payload.get("session_id") or payload.get("id") or "")
            continue

        payload_type = payload.get("type")
        if item.get("type") == "event_msg" and payload_type == "task_started":
            turn_id = str(payload.get("turn_id") or "")
            if turn_id:
                current = Turn(
                    agent="codex",
                    turn_id=turn_id,
                    conversation_id=conversation_id,
                    timestamp_ns=timestamp_ns,
                )
            continue

        if current is None:
            continue

        if item.get("type") == "turn_context":
            if str(payload.get("turn_id") or "") == current.turn_id and isinstance(payload.get("model"), str):
                current.model = payload["model"]
            continue

        if item.get("type") == "response_item" and payload_type in {"custom_tool_call", "function_call"}:
            call_id = str(payload.get("call_id") or payload.get("id") or "")
            name = str(payload.get("name") or "unknown")
            if call_id:
                current.tool_names[call_id] = name
                current.tool_calls += 1
            continue

        if item.get("type") == "response_item" and payload_type in {
            "custom_tool_call_output",
            "function_call_output",
        }:
            call_id = str(payload.get("call_id") or "")
            if not call_id:
                continue
            success = explicit_tool_success(payload.get("output"))
            if success is False:
                current.tool_failures += 1
            records.append(
                tool_record(
                    source=path,
                    turn=current,
                    call_id=call_id,
                    name=current.tool_names.get(call_id, "unknown"),
                    timestamp_ns=timestamp_ns,
                    success=success,
                )
            )
            stats.tools += 1
            continue

        if item.get("type") == "event_msg" and payload_type == "task_complete":
            if str(payload.get("turn_id") or "") != current.turn_id:
                continue
            if isinstance(payload.get("duration_ms"), int):
                current.duration_ms = payload["duration_ms"]
            if isinstance(payload.get("time_to_first_token_ms"), int):
                current.ttft_ms = payload["time_to_first_token_ms"]
            current.timestamp_ns = timestamp_ns
            records.append(turn_record(current, path))
            stats.turns += 1
            current = None

    return records


def find_transcripts(root: Path, max_files: int | None) -> list[Path]:
    if not root.exists():
        return []
    files = sorted(root.rglob("*.jsonl"), key=lambda path: path.stat().st_mtime, reverse=True)
    return files if max_files is None else files[:max_files]


def payload_for(records: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "resourceLogs": [
            {
                "resource": {
                    "attributes": attributes(
                        {
                            "service.name": SERVICE_NAME,
                            "deployment.environment.name": "local",
                        }
                    )
                },
                "scopeLogs": [
                    {
                        "scope": {"name": SCOPE_NAME},
                        "logRecords": records,
                    }
                ],
            }
        ]
    }


def send_batches(endpoint: str, records: list[dict[str, Any]], batch_size: int) -> None:
    for offset in range(0, len(records), batch_size):
        body = json.dumps(payload_for(records[offset : offset + batch_size])).encode()
        request = urllib.request.Request(
            endpoint,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            if response.status not in {200, 202}:
                raise RuntimeError(f"OTLP endpoint returned HTTP {response.status}")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--agent", choices=["both", "claude", "codex"], default="both")
    result.add_argument("--claude-root", type=Path, default=Path.home() / ".claude/projects")
    result.add_argument("--codex-root", type=Path, default=Path.home() / ".codex/sessions")
    result.add_argument("--endpoint", default="http://127.0.0.1:4318/v1/logs")
    result.add_argument("--days", type=int, default=14, help="Only emit records newer than this many days")
    result.add_argument("--max-files", type=int)
    result.add_argument("--batch-size", type=int, default=500)
    result.add_argument("--send", action="store_true", help="Send data; otherwise perform a dry run")
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if args.days < 1 or args.batch_size < 1:
        print("--days and --batch-size must be positive", file=sys.stderr)
        return 2

    stats = ParseStats()
    records: list[dict[str, Any]] = []
    if args.agent in {"both", "claude"}:
        for path in find_transcripts(args.claude_root, args.max_files):
            records.extend(parse_claude(path, stats))
    if args.agent in {"both", "codex"}:
        for path in find_transcripts(args.codex_root, args.max_files):
            records.extend(parse_codex(path, stats))

    cutoff = int((datetime.now(timezone.utc) - timedelta(days=args.days)).timestamp() * 1_000_000_000)
    records = [record for record in records if int(record["timeUnixNano"]) >= cutoff]
    records.sort(key=lambda record: int(record["timeUnixNano"]))

    mode = "send" if args.send else "dry-run"
    print(
        f"mode={mode} files={stats.files} lines={stats.lines} "
        f"skipped_lines={stats.skipped_lines} parsed_turns={stats.turns} "
        f"parsed_tools={stats.tools} selected_records={len(records)}"
    )
    if args.send and records:
        send_batches(args.endpoint, records, args.batch_size)
        print(f"sent_records={len(records)} endpoint={args.endpoint}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
