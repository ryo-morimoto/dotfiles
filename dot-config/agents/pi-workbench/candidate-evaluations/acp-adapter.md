# Candidate Evaluation: acp-adapter

Source: `https://github.com/beyond5959/acp-adapter`
Current ref: `491151b16846682396aca8c31e9285e414e4f3b8`
Role: Zed ACP bridge to Pi.

## Install

Tried: not yet.

Command to try:

```sh
npm install -g acp-adapter
```

## Minimal Config

```sh
acp-adapter --adapter pi --pi-provider openai-codex --pi-model <model>
```

## Smoke Command

Run from a disposable project with Zed configured to use the standalone ACP
command above.

## Contracts

| Contract | State | Notes |
| --- | --- | --- |
| Zed starts a Pi-backed ACP session. | pending | Needs Zed integration smoke. |
| Prompt output streams back to Zed. | pending | Verify token streaming, not only final response. |
| Pi session list/load works through ACP. | pending | Include reload after process restart. |
| Bash/write/edit permission gates appear in Zed. | pending | Must preserve Pi permission semantics. |
| Model and thinking config are changeable or documented as fixed. | pending | Document any fixed fields. |

## Decision

Use by default. Do not build a local ACP adapter unless this candidate blocks
the MVP and upstream patching is not viable.
