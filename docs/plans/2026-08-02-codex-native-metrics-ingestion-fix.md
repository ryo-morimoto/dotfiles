---
title: "fix: Ingest Codex native Delta metrics into Prometheus"
type: fix
status: implemented
date: 2026-08-02
---

# Codex native metrics ingestion fix plan

## Problem frame

Codex 0.146.0 から logs と traces は Grafana LGTM に届いているが、Prometheus に
`codex_*` native metrics が存在せず、Codex の latency/tool panels が空になっている。

実測では OpenTelemetry Collector の OTLP/gRPC receiver が metric points を受理し、
receiver failure/refusal は 0 である。一方、Prometheus 向け
`otlp_http/metrics` exporter の failure counter が増加している。したがって障害点は
Codex -> Collector ではなく Collector -> Prometheus OTLP receiver である。

## Root cause

Codex 0.146.0 は OTLP metric exporter を `Temporality::Delta` で構築する。
Prometheus 3.13.1 は Delta OTLP metrics を既定では drop し、experimental feature
`otlp-deltatocumulative` を有効にした場合だけ cumulative series へ変換する。

現在の Prometheus flags は次の状態である。

```text
web.enable-otlp-receiver = true
enable-feature = exemplar-storage
```

`otlp-deltatocumulative` がないため、Codex native metrics だけが保存されない。logs と
traces には Delta/Cumulative temporality がないため影響しない。

## Decisions

### Use Prometheus embedded Delta-to-Cumulative conversion

Prometheus の起動 flag に次を追加する。

```text
--enable-feature=otlp-deltatocumulative
```

選定理由:

- Prometheus 自身が OTLP backend 用として案内している経路である。
- 既存 dashboard は `rate()` / `increase()` / `histogram_quantile()` を使うため、raw
  Delta 保存ではなく cumulative 変換が必要である。
- `otlp-native-delta-ingestion` は標準の `rate()` / `increase()` と互換でなく、公式にも
  early-stage とされるため採用しない。
- Collector の `deltatocumulative` processor でも変換可能だが、v0.157.0 時点で alpha
  であり、単一 Prometheus backend のため変換責務を二重化しない。

Prometheus embedded converter も同じ stateful processor を使用する。再起動時に
in-memory accumulation state が失われるため、cumulative series には counter reset が
発生する。PromQL の `rate()` と `increase()` は reset を扱えるため、これは許容する。

### Keep the default Prometheus translation strategy

`otlp.translation_strategy` は既定の `UnderscoreEscapingWithSuffixes` を維持する。
suffix を無効化して現在の dashboard query に合わせる方法は、metric collision の可能性が
あり、Prometheus documentation でも非推奨寄りの選択肢として扱われるため採用しない。

Codex 0.146.0 と Prometheus 3.13.1 が使用する translator v1.0.0 から、保存後の主要名は
次のように確定できる。

| OTel instrument | Prometheus series family |
| --- | --- |
| `codex.responses_api.inference_time.duration_ms` unit=`ms` | `codex_responses_api_inference_time_duration_ms_milliseconds_*` |
| `codex.responses_api.overhead.duration_ms` unit=`ms` | `codex_responses_api_overhead_duration_ms_milliseconds_*` |
| `codex.websocket.request` | `codex_websocket_request_total` |
| `codex.websocket.request.duration_ms` unit=`ms` | `codex_websocket_request_duration_ms_milliseconds_*` |
| `codex.websocket.event` | `codex_websocket_event_total` |
| `codex.websocket.event.duration_ms` unit=`ms` | `codex_websocket_event_duration_ms_milliseconds_*` |
| `codex.tool.call` | `codex_tool_call_total` |
| `codex.tool.call.duration_ms` unit=`ms` | `codex_tool_call_duration_ms_milliseconds_*` |

Classic histogram queries use the `_bucket`, `_sum`, and `_count` children of each `*` family.

### Keep the current resource-label promotion

LGTM の Prometheus config は `service.name` を既に resource label として promote している。
そのため native series では `service_name="codex_cli_rs"` が利用できる。Codex metrics の
instrument attributes には `model`、`tool`、`success` などが含まれるため、dashboard の
grouping labels は維持する。Collector transform と Prometheus YAML は変更しない。

## Scope

### Files to modify

| Path | Change |
| --- | --- |
| `nix-config/hosts/ryobox/agent-observability.nix` | Prometheus Delta conversion flag を追加 |
| `nix-config/hosts/ryobox/agent-observability/grafana/agent-latency.json` | Codex histogram query を unit-suffixed metric 名へ更新 |
| `dot-config/agents/telemetry/README.md` | Delta temporality、保存名、検証・reset caveat を記載 |

### Non-goals

- 既に drop された過去の native metrics を復元しない。
- logs/traces や backfill parser を変更しない。
- Prometheus translation strategy を変更しない。
- native Delta ingestion や Collector-side conversion を同時に有効にしない。
- Claude Code の telemetry が未到着である問題は別の probe とする。

## Implementation units

### U1. Enable Prometheus Delta conversion

`PROMETHEUS_EXTRA_ARGS` は現在 retention flag 一つだけを渡している。空白を含む environment
value を一つの Docker argument として保持する。

```nix
-e 'PROMETHEUS_EXTRA_ARGS=--storage.tsdb.retention.time=14d --enable-feature=otlp-deltatocumulative' \
```

LGTM の `run-prometheus.sh` はこの値を shell words に分割し、組み込みの
`--enable-feature=exemplar-storage` と並べて Prometheus へ渡す。Prometheus 3.13.1 の
parser が複数の `--enable-feature` を受理することはローカル image で確認済みである。

### U2. Correct Codex histogram queries

runtime verification で Codex 0.146.0 が `codex.api_request` ではなく
`codex.responses_api.inference_time.duration_ms` を export することを確認した。dashboard は
次の family を参照する。

```text
codex_responses_api_inference_time_duration_ms_milliseconds_bucket

codex_tool_call_duration_ms_milliseconds_bucket
```

counter query `codex_tool_call_total` は既に変換後の名前と一致するため変更しない。
`service_name`、`model`、`tool`、`success` grouping も維持する。

`success="false"` series は最初の失敗まで存在しない。成功した tool call がある期間を
no data ではなく 0% と表示するため、failure-rate query は total series の zero-valued
fallback を `or` で結合してから total で除算する。tool call 自体がない期間は no data の
ままとする。

JSON を編集後、`jq empty` と dashboard query の exact-name scan を行う。

### U3. Update operations documentation

telemetry README に次を追加する。

- Codex 0.146.0 は Delta metrics を送ること。
- Prometheus の conversion flag が必須であること。
- 再起動時に conversion state が reset されること。
- metric 名は Prometheus API で確認してから dashboard に使うこと。
- pre-fix の metrics は backfill されないこと。

### U4. Static verification

実装後、rebuild 前に次を実行する。

```bash
nixfmt nix-config/hosts/ryobox/agent-observability.nix
jq empty nix-config/hosts/ryobox/agent-observability/grafana/agent-latency.json
nix flake check ./nix-config
git diff --check
```

生成される container command に retention と Delta conversion の両 flag が含まれることも
評価結果または build artifact から確認する。

### U5. Roll out and produce a controlled sample

1. `sudo nixos-rebuild switch --flake ./nix-config#ryobox` を実行する。
2. Prometheus runtime flags API で `exemplar-storage` と
   `otlp-deltatocumulative` の両方を確認する。
3. 新しい interactive Codex session を開始する。
4. non-sensitive directory で API request 一回、成功 tool call 一回を発生させる。
5. 10秒以下の poll を繰り返し、最初の native metric sample が現れるまで最大90秒待つ。
6. 同じ session で二回目の API request、成功 tool call、意図した失敗 tool call を発生させる。
7. 二つ目の sample timestamp が現れるまで再度 poll する。
8. Codex を正常終了して final force flush を発生させる。

`codex exec` は metrics が欠ける既知差異があるため acceptance sample に使わない。
Codex は export interval を明示的に上書きせず OTel `PeriodicReader` の既定値を使う。短い
session の shutdown flush 一回だけでは `rate()` に必要な二点を作れないため、二つの export
batch を確認してから dashboard を判定する。

### U6. Verify ingestion before trusting the dashboard

Prometheus API から metric 名を列挙し、最低限次を確認する。

```text
codex_responses_api_inference_time_duration_ms_milliseconds_bucket
codex_tool_call_total
codex_tool_call_duration_ms_milliseconds_bucket
```

各 family について次を確認する。

- `service_name="codex_cli_rs"` が存在する。
- API metrics に `model`、tool metrics に `tool` と `success` が存在する。
- histogram に `_bucket`、`_sum`、`_count` が存在する。
- `rate()`、`increase()`、`histogram_quantile()` が non-empty result を返す。
- Collector の `otelcol_exporter_send_failed_metric_points_total` が、新しい Codex sample の
  export interval 中に増加しない。
- `otelcol_receiver_failed_metric_points_total{receiver="otlp"}` と refused counter が 0 の
  ままである。

Exporter failure が残る場合のみ、`ENABLE_LOGS_OTELCOL=true` を一時的に有効化して一回の
sample を再現し、Prometheus response error を取得する。恒久的な verbose logging は行わない。

### U7. Verify Grafana panels

Grafana provisioning 後、次の Codex panels が non-empty になることを確認する。

- API request duration p50/p95
- Tool duration p50/p95
- Tool call count
- Tool failure rate

raw logs/traces panelsが引き続き表示されることも確認する。dashboard の query inspector と
Prometheus API の結果が異なる場合は、実際の stored metric name/labels を優先して JSON を
修正する。

## Acceptance criteria

- **WHEN** rebuilt Prometheus の flags API を読む、**THEN**
  `otlp-deltatocumulative` と `exemplar-storage` が両方有効である。
- **WHEN** fresh interactive Codex session で API/tool activity を発生させる、**THEN**
  `codex_*` counter と histogram series が Prometheus に現れる。
- **WHEN** native Codex metric を受信する、**THEN** Collector metrics exporter failure は
  増加しない。
- **WHEN** dashboard を開く、**THEN** Codex の latency、tool count、failure-rate panels が
  non-empty になる。
- **WHEN** container を再起動する、**THEN**既存 TSDB data は残り、新しい cumulative
  series は reset として扱われ、query error にならない。
## Rollback

1. `PROMETHEUS_EXTRA_ARGS` から `--enable-feature=otlp-deltatocumulative` を削除する。
2. dashboard query を元に戻す必要はない。native series の historical data は TSDB に残るが、
   新しい sample が止まるだけである。
3. rebuild して container を再作成する。

rollback は `/var/lib/agent-observability` を削除せず、logs/traces と既に保存された metrics を
保持する。

## Evidence and references

- Codex 0.146.0 metrics client explicitly selects `Temporality::Delta`:
  <https://github.com/openai/codex/blob/rust-v0.146.0/codex-rs/otel/src/metrics/client.rs#L297-L304>
- Prometheus OTLP Delta conversion guide:
  <https://prometheus.io/docs/guides/opentelemetry/#delta-temporality>
- Prometheus feature behavior and restart/reset caveat:
  <https://prometheus.io/docs/prometheus/latest/feature_flags/#otlp-delta-conversion>
- Prometheus OTLP translator v1.0.0 unit naming:
  <https://github.com/prometheus/otlptranslator/blob/v1.0.0/metric_namer.go>
- Collector-side Delta-to-Cumulative processor status and defaults:
  <https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.157.0/processor/deltatocumulativeprocessor/README.md>
