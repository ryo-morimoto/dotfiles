# Pi Workbench Smoke Runner

Runs the non-interactive Pi workbench smoke checks and writes a receipt under:

```text
dot-config/agents/pi-workbench/verification/receipts/
```

## Usage

```sh
tools/pi-workbench-smoke/pi-workbench-smoke
```

Useful options:

```sh
tools/pi-workbench-smoke/pi-workbench-smoke --quick
tools/pi-workbench-smoke/pi-workbench-smoke --keep-temp
tools/pi-workbench-smoke/pi-workbench-smoke --receipt /tmp/pi-smoke.md
```

`--quick` skips the heavier GitHub clone/build/test checks and only runs local command/package checks.

## Boundary

This runner intentionally does not mutate live `~/.pi`, `~/.codex`, Zed config, or MCP client config. It uses disposable
Pi directories and records the remaining live checks as blocked/manual.

