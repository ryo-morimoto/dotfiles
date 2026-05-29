# Local Models Evaluation

Candidate: Pi custom model config and pi-ai providers
Date checked: 2026-05-29
Registry check: `@earendil-works/pi-coding-agent@0.77.0`; `@mariozechner/pi-coding-agent@0.73.1`

## Contract

- At least one small local/open-weight model handles memory extraction.
- At least one small local/open-weight model handles session summarization.
- At least one stronger local/open-weight model handles read-only code review.
- Patch authoring stays on the strongest reliable model until local models pass tests.
- No credential material enters model logs, memory, telemetry, or session exports.

## Provider Endpoints To Try

- Ollama OpenAI-compatible endpoint.
- llama.cpp server with OpenAI-compatible endpoint.
- vLLM OpenAI-compatible endpoint.
- LM Studio OpenAI-compatible endpoint.

## Minimal Config To Try

Use `config.examples/models/pi-models.example.json` and keep routing manual by task.

## Smoke Commands

```text
summarize a local markdown file with the small model
review a tiny read-only diff with the review model
attempt patch authoring only after the review model passes deterministic checks
```

## Observed Behavior

`@earendil-works/pi-coding-agent@0.77.0` is available and provides the `pi` bin. Local `node --version` is `v24.15.0`.

No local/open-weight endpoint was configured in this repository harness, so summarization/review model behavior was not
exercised. Current Pi package names show both `@earendil-works` and older `@mariozechner` package lineages; prefer the
active package used by selected Pi packages.

## Disposition

Use provider endpoints and Pi config. Do not build a router for MVP.

## Local Adapter Justified?

No.
