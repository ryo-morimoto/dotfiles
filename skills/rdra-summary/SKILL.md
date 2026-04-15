---
name: rdra-summary
description: This skill should be used to produce a non-technical stakeholder summary of the current RDRA Google Sheet. Layer-by-layer prose (System Value → External Environment → System → Boundary order) without technical vocabulary. Uses RDRA 3.0 Context grouping to structure the system-layer narrative. Target length 1000-2000 Japanese characters. Triggers on "ステークホルダー向け要約", "RDRA を業務説明に", "非エンジニア向けに RDRA をまとめて".
---

# rdra-summary

現状の RDRA シートから、業務ステークホルダー向けの散文サマリを生成する狭い入口。read-only。

## Shared context

- `../rdra-shared/methodology.md` (4 層の意味、Context grouping)
- `../rdra-shared/sheet-schema.md`

## Workflow

### Step 1: Read

`gws sheets spreadsheets values get` (`../rdra-shared/gws-operations.md` §2) で 9 ソースシート + `UC_PIVOT` を取得。

### Step 2: Context grouping (RDRA 3.0)

システム層の要素 (`情報` / `状態` / `条件` / `バリエーション`) は各シートの **A 列 `コンテキスト`** に first-class でグルーピングが書かれている。これを段落の構造にそのまま使う。同じ `コンテキスト` 値を持つ行が 1 段落に相当する。

### Step 3: Compose prose

出力は以下の 4 セクション。順序は Value → External → System → Boundary invariant を守る。

```markdown
## システムがもたらす価値
誰のどんな課題を解決するか。アクター・BUC から導出。
(システム価値層から)

## 業務の全体像
主要な業務の流れと、どの業務がシステムを使うか。
(外部環境層: BUC + 業務フロー)

## システムが扱うこと
情報と状態、ビジネスルールの全体像。Context グループごとに 1 段落。
(システム層: 情報 + 状態 + 条件 + バリエーション、3.0 Context grouping で構造化)

## システムとの接点
ユーザが触る画面と、システムが外部に出すイベント。
(境界層: UC + 画面 + イベント)
```

### Step 4: Vocabulary filter

以下の語は **絶対に使わない** (技術語彙禁止):

- テーブル名, カラム名
- クラス名, 型名, 関数名
- API endpoint, HTTP メソッド, ステータスコード
- SQL, JSON, YAML 等のフォーマット名
- 内部フレームワーク名 (Rails, Django, Next.js ...)

変換例:
- `customer_master_tbl` → `顧客情報`
- `POST /invoices` → `請求書を登録する操作`
- `status = 'pending'` → `承認待ちの状態`

### Step 5: Hotspot handling

hotspot `[?]` が残っているセルは「検討中」と訳す。例: `顧客が注文を確定する [?]` → 「顧客が注文を確定する操作 (現在検討中)」。

### Step 6: Length check

- 目標: 1000-2000 文字 (日本語)
- 2000 文字超過 → 要約をもう一段階抽象化して再試行
- 500 文字未満 → シートの情報量が不足している可能性を警告し、`rdra-check` の実行を推奨

## Write behavior

**None.** 出力は markdown テキストのみ。シートへは書かない。

## Non-goals

- 技術詳細を含む設計資料
- レビュー → `rdra-review`
- 整合性チェック → `rdra-check`
