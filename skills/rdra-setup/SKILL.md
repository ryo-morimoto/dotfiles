---
name: rdra-setup
description: This skill should be used when starting a brand-new RDRA (Relationship Driven Requirement Analysis) requirement definition from scratch against the official RDRA Google Sheet template. Triggers on "RDRA立ち上げ", "新規要件定義をRDRAで", "RDRA setup", "RDRA で要件整理を始めたい". Walks the user through 3 phases (Phase 1 基盤 time-boxed at ~10% of project, Phase 2 要件形成, Phase 2 gate, Phase 3 仕様化準備) using the 9 RDRA source sheets (アクター / 外部システム / 情報 / 状態 / BUC / 条件 / バリエーション / 機能要求 / 非機能要求). Does NOT apply to existing systems (use rdra-reverse) or meeting note ingestion (use rdra-ingest).
---

# rdra-setup

新規 RDRA 要件定義を立ち上げる狭い入口。ユーザは skill 名だけ覚えればよく、9 ステップの詳細は references に隠す。

## Shared context (read these first)

- `../rdra-shared/methodology.md` — 4 層 × 3 フェーズ × 9 ステップと invariants
- `../rdra-shared/sheet-schema.md` — 9 source sheets と触ってはいけない派生タブ (live 検証済み列構成)
- `../rdra-shared/gws-operations.md` — `gws` コマンドテンプレ (list / read / append / update)
- `../rdra-shared/guardrails.md` — pre-write checklist と refusal list
- `../rdra-shared/anti-patterns.md`

## Initial setup

初回起動時にユーザから取得し、`.rdra-config.toml` (cwd) に保存:

1. **Spreadsheet ID** — 先に公式テンプレ (`docs.google.com/spreadsheets/d/1h7J70l6DyXcuG0FKYqIpXXfdvsaqjdVFwc6jQXSh9fM/`) を File → Make a copy で複製した自分の ID
2. **Project total duration** — Phase 1 の time-box (10%) 計算に使う
3. **Project goal** — 1 行で目的

既に config があれば読み込むだけ。

## Workflow

Layer traversal order は **Value → External → System → Boundary**。これを崩さない。

### Phase 1: 基盤 (Steps 1-4, time-box ≈ 10% of project)

粗くてよい。完璧を追わない (iterate-don't-complete invariant)。

1. **Step 1** — 「誰がこのシステムに関わりますか？業務単位で 5-10 個」→ `アクター` / `外部システム` シートに append (分離していることに注意)
2. **Step 2** — 「各アクターがこのシステムで何をする？業務粒度で」→ `BUC` シート A 列 (業務), B 列 (BUC), D 列 (アクティビティ) に粗く。`先`/`次` (C/E) と UC 名 (F) は空で良い
3. **Step 3** — 「業務で管理したい情報は ID 単位で何？」→ `情報` シートに append。`コンテキスト` 列 (A) で業務単位のグループ化を意識。DB テーブルに引きずられない (anti-pattern #2)
4. **Step 4** — 「情報がどう変化する？開始/進行中/完了 のような軸」→ `状態` シートに append。`状態モデル` 列 (B) で情報シートの行と名前一致させる

**Phase 1 完了判定:** `アクター` / `外部システム` / `情報` / `状態` / `BUC` の 5 シートすべてに最低 1 行 + 主要な業務の BUC が粗く並んでいる。**time-box 超過時は強制的に Phase 2 へ**。不確かな箇所は hotspot `[?]` を付けて残す。

### Phase 2: 要件形成 (Steps 5-6)

5. **Step 5** — 各 BUC アクティビティに対応する UC を F 列に埋める (`XXXをYYYする` 形式)。並行して `機能要求` / `非機能要求` シートにアクター駆動で要求を洗い出す。
6. **Step 6** — BUC の generic relation (G-J 列) を埋める。`関連モデル1` (G) に `アクター`/`情報`/`状態`/`外部システム`/`条件`/`バリエーション` のいずれかを書き、`関連オブジェクト1` (H) に該当シートの名前を書く。2 つ目の関係が必要なら I/J を使う。3 つ以上は同じ UC を複数行に分ける。参照先シートに名前が無ければ同時に追加する。

**Phase 2 gate:** ユーザに問う: 「この範囲で見積もり可能か？」YES なら Phase 3 に進まず設計フェーズへ移る選択肢あり (成熟チームの通常ルート)。

### Phase 3: 仕様化準備 (Steps 7-9)

7. **Step 7** — UC ごとに条件を紐付け。`条件` シートに append (B 列 条件, C 列 説明)。実装ルールは入れない (anti-pattern #3)。
8. **Step 8** — 条件軸でバリエーション抽出。`バリエーション` シートに append (B 列 バリエーション, C 列 値)。
9. **Step 9** — 条件 × バリエーションの具体要素を詳細化し、全シートの `コンテキスト` 列で結線 (Context grouping)。最後に `rdra-check` を呼んで整合確認。

## Write path

`gws sheets` を直接叩く。コマンドテンプレートは `../rdra-shared/gws-operations.md` を参照。書き込み前に `../rdra-shared/guardrails.md` の allowlist を必ず確認する (source 9 シート以外への書き込みは自己 refuse)。

## Exit conditions

- Phase 2 gate で停止 (設計フェーズへ引き継ぎ)
- Phase 3 完了 (全シートに hotspot なしの行が揃う)
- time-box 大幅超過 → 退却して `rdra-review` へ

## Non-goals

- 議事録取り込み → `rdra-ingest`
- 既存システム可視化 → `rdra-reverse`
- 整合性チェック → `rdra-check`
- レビュー → `rdra-review`
