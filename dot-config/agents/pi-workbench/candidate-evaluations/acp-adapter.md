# acp-adapter Evaluation

Candidate: `beyond5959/acp-adapter`
Date checked: 2026-05-29
Source checked: GitHub HEAD `491151b16846682396aca8c31e9285e414e4f3b8`

## Contract

- Zed can start a Pi-backed ACP session.
- Prompts stream responses back to Zed.
- Pi session new/list/load works through the bridge.
- Bash/write/edit permission prompts remain visible in Zed.
- Model and thinking config are either configurable or documented as fixed.

## Install Command To Try

```sh
git clone https://github.com/beyond5959/acp-adapter /tmp/acp-adapter
```

Use the repository-documented build/install command from that checkout. The npm name `acp-adapter` was not published
on the public npm registry when checked.

## Minimal Config To Try

```json
{
  "adapter": "pi",
  "piProvider": "openai-codex",
  "piModel": "REPLACE_WITH_MODEL"
}
```

## Smoke Command

```sh
acp-adapter --adapter pi --pi-provider openai-codex --pi-model REPLACE_WITH_MODEL
```

## Observed Behavior

Local source smoke was run from a shallow clone. `go test ./cmd/... ./internal/... ./pkg/...` passed, `go build
./cmd/acp` passed, and CLI help lists Pi flags including `--pi-bin`, `--pi-provider`, `--pi-model`, `--pi-session-dir`,
and `--pi-disable-gate`.

Full `go test ./...` failed in `test/integration` at `TestE2EACPPlanUpdateMappedFromTurnPlanUpdated` with one missing
plan update. Zed ACP interactive session smoke was not run from this non-interactive harness.

Receipt: `verification/receipts/2026-05-29-local-smoke.md`.

## Disposition

Adopt first. Do not build a local ACP server. If MCP routing, filesystem write bridging, or custom extension UI support
blocks usage, patch or fork `acp-adapter` before adding local code here.

## Local Adapter Justified?

No.
