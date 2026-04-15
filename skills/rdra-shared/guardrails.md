# RDRA Skill Guardrails

全 skill が書き込み前・レビュー前に従う共通ルール。

## Pre-write checklist

`gws sheets spreadsheets values append` / `update` を呼ぶ前に必ず満たす:

1. **Target is a source sheet** — 書き込み許可は 9 枚のみ: `アクター` / `外部システム` / `情報` / `状態` / `BUC` / `条件` / `バリエーション` / `機能要求` / `非機能要求`
2. **Name matches existing rows exactly** — BUC の `関連オブジェクト1/2` (H/J 列) の値は `関連モデル1/2` (G/I 列) で指定したシートに実在する名前であること
3. **No implementation rules in 条件** (null チェック, 文字列長, API ステータスコード等はアンチパターン #3 で排除)
4. **No DB tables as 情報** (reverse engineering 時、物理テーブル名をそのまま情報にしない。アンチパターン #2)
5. **Layer assignment follows RDRA 3.0** (条件/バリエーションはシステム層)
6. **Phase 1 time-box not exceeded** (setup skill 限定、超過時は Phase 2 に強制進行)

## Hotspot marker convention

曖昧な値を落とさずに保持するための印。

- セル値の末尾に半角スペース + `[?]` を付与
- 例: `顧客が注文を確定する [?]` — アクター未確定
- 解決時は `[?]` を除去
- `rdra-check` / `rdra-review` が `[?]` を検出して報告

これにより「曖昧だから書かない」ではなく「曖昧と明示して書く」を徹底する。

## Iteration rule

skill は以下を **しない**:

- 単一シートの完成チェックで処理を止める
- 「このセルが空だからエラー」と throw する
- 網羅的な埋め尽くしをユーザに強要する

skill は以下を **する**:

- 欠損を hotspot 付きで記録
- 次の 1 手を提示 (複数候補ではなく推奨 1 つ)
- 全体整合の劣化を警告し、劣化時は差分 revert を提案

## Write path

```
user intent
  → diff proposal (per sheet)
  → allowlist pre-check (this file) — skill が target シート名を照合
  → user approval
  → gws sheets spreadsheets values append / update (コマンドテンプレは gws-operations.md)
  → consistency recheck via `'✖不整合'` tab read
  → diff report
```

Agent 自身が allowlist チェックの執行者。Python wrapper は持たない (YAGNI)。書き込み許可されるのは 9 source シートのみ。派生タブ (`✖不整合` / `UC_PIVOT` / `■関連データ` / `ZeroOne`) と分析タブは呼ばない。

## Refusal list

skill が実行を拒否する状況:

- 派生タブ (`✖不整合` / `UC_PIVOT` / `■関連データ` / `ZeroOne`) への書き込み指示 (アンチパターン #10)
- 分析ワークタブ (`参照設定` / `分析準備` / `関連WK` / `モデル分析準備` / `情報分析` / `状態分析` / `条件分析`) への書き込み指示 (ツール管理領域)
- 情報シートに DB テーブル名そのままの追加 (アンチパターン #2 検出時)
- 条件シートに実装ルール文言 (`null`, `length`, `HTTP`, `timeout` など) の追加
- 参照系 UC を 5 個超えて一度に追加する指示 (アンチパターン #7)

拒否時は必ず理由 (アンチパターン番号 + 出典) をユーザに提示する。
