---
name: rdra-review
description: This skill should be used to review an RDRA Google Sheet produced by someone else (or a previous session). Runs rdra-check logic internally for structural issues, adds severity-graded anti-pattern detection, suggests RDRAGraph visual views for verification, and emits a prioritized review comment list anchored to specific cell references. Read-only; proposes but does not apply fixes. Triggers on "RDRA レビュー", "review this RDRA", "このシートを見てほしい".
---

# rdra-review

他人 (or 過去セッション) が書いた RDRA をレビューする狭い入口。read-only。

## Shared context

- `../rdra-shared/methodology.md`
- `../rdra-shared/sheet-schema.md`
- `../rdra-shared/anti-patterns.md`
- `../rdra-shared/guardrails.md`

## Workflow

### Step 1: Structural issues (rdra-check 相当)

`rdra-check` の Mode A ロジックを内部実行:

- 不整合タブ読み取り
- UC_PIVOT でのクロスチェック
- Orphan detection
- Anti-pattern scan

### Step 2: Severity grading

検出された issue に severity を付ける:

| Severity | 定義 | 例 |
|---|---|---|
| **Critical** | 結合破綻 or 派生タブ汚染 | 名前不一致で cross-reference が切れている / 派生タブに書き込まれている |
| **High** | 手法の根幹を壊す | 情報が DB テーブル形状 (#2), 条件に実装ルール (#3) |
| **Medium** | レビュー推奨 | 参照 UC 爆発 (#7), アクタードリフト (#6), 業務フロー飛ばし (#5) |
| **Low** | 進行中として許容範囲 | hotspot `[?]` 残存, Phase 1 time-box 内の欠損 |

### Step 3: RDRAGraph visual hints

以下の view を開いて目視確認することを推奨 (https://www.rdra.jp/rdraツール/rdragraphツール):

- **All UC** — UC 全体像
- **Business-Context** — 外部環境の把握
- **BUC-Actor Groups** — アクターカバレッジ
- **Information Model** — 情報シート健全性
- **State-Related UCs** — 状態遷移と UC の紐付き

skill はリンクを案内するだけで、図を再生成しない。

### Step 4: Failure mode detection

rdra.jp/要件定義の進め方 の 4 失敗モードの兆候をスキャン:

- **目的不明** — 要求モデルや goal statement が欠落
- **ゴール曖昧** — UC の完了条件が書かれていない
- **議論のデッドロック** — hotspot `[?]` が特定セルに 3 週間以上残る (タイムスタンプがあれば)
- **思いつきの羅列** — BUC に紐付かない孤立 UC が多数

### Step 5: Emit review comments

優先度順に列挙し、セル参照で anchor:

```
## Critical (要即修正)
- [BUC!H7] 関連オブジェクト1 '営業部' が `アクター` シートに存在しない (関連モデル1=アクター なのに参照切れ)
- [ZeroOne tab] 派生タブに手書きが混入。次回リフレッシュで消えるため source cells へ移動

## High (手法レベルの問題)
- [情報!B3] 'customer_master_tbl' は DB 命名。'顧客' に置換推奨 (anti-pattern #2)
- [条件!B5] 'HTTPステータスが500でない' は実装ルール。除外推奨 (anti-pattern #3)

## Medium
- [BUC!F12-F30] 参照系 UC が 19 個。最小限に絞るのが 3.0 の指針 (anti-pattern #7)

## Low
- [BUC!F8] hotspot '[?]' が残存

## Suggested visual checks (RDRAGraph)
- Open 'Information Model' view → 情報シートの健全性
- Open 'BUC-Actor Groups' view → アクターカバレッジ
```

## Write behavior

**None.** 修正提案のみを返す。実行は `rdra-ingest` 経由でユーザが承認。

## Non-goals

- 自動修正
- 単独の整合チェック → `rdra-check`
- ステークホルダー向け要約 → `rdra-summary`
