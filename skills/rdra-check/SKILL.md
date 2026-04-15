---
name: rdra-check
description: This skill should be used to verify consistency of an RDRA Google Sheet. Reads the formula-driven ✖不整合 tab, the UC_PIVOT tab (the 3.0 main validation lens), and performs orphan detection + anti-pattern scanning across the 9 source sheets. Two modes, full check (default) and phase-2 estimation gate. Read-only; never writes. Triggers on "RDRA check", "整合性確認", "Phase 2 gate", "見積もり可能か判定".
---

# rdra-check

RDRA シートの整合性検証。read-only。

## Shared context

- `../rdra-shared/methodology.md` (Phase 2 gate の条件)
- `../rdra-shared/sheet-schema.md` (cross-reference 規則、派生タブ一覧)
- `../rdra-shared/anti-patterns.md`
- `../rdra-shared/guardrails.md`

## Modes

### Mode A: Full check (default)

1. **不整合タブ読み取り** — `gws sheets spreadsheets values get` で `'✖不整合'` タブ (シングルクォート必須) を取得し、数式ベースの検出結果をそのまま報告する。skill 側で再実装しない (公式シートが正)。コマンドテンプレは `../rdra-shared/gws-operations.md` §2。
2. **UC_PIVOT タブ読み取り** — 3.0 の主検証レンズ。チェック:
   - すべての UC に少なくとも 1 人のアクターが紐付いている (BUC の generic relation で G or I が `アクター`)
   - すべての UC に少なくとも 1 つの情報 or 状態参照がある
   - どの BUC にも属さない UC が無い
3. **Orphan detection** (シート横断、名前一致ベース):
   - `アクター` / `外部システム` / `情報` / `状態` / `条件` / `バリエーション` のどれかに定義されているが BUC の `関連オブジェクト1/2` (H/J 列) から一度も参照されていない名前
   - `機能要求` / `非機能要求` で `アクター` 列の値が `アクター` シートに存在しない行
   - `状態` シートの `状態モデル` 列の値が `情報` シートに存在しない行
   - `条件` シートの `バリエーション` / `状態モデル` 列の値が対応シートに存在しない行
4. **Anti-pattern scan** (`anti-patterns.md` と照合):
   - 情報名が DB テーブル命名規則 (`t_`, `_master`, `_tbl` 等) に見える → #2
   - 条件に実装用語 (`null`, `length`, `HTTP`, `timeout`) → #3
   - 参照系 UC が過剰に多い → #7
   - hotspot `[?]` が大量に残っている → #9 (Phase 1 time-box 超過疑い)

### Mode B: Phase 2 estimation gate

Phase 2 → Phase 3 (or 設計) に移るか判断するための軽量チェック:

- すべての BUC に少なくとも 1 UC (BUC シートで同じ業務/BUC に属する F 列が非空)
- すべての UC に アクター + 情報 or 状態 の 2 軸が紐付いている (G-J 列で確認)
- `機能要求` / `非機能要求` が最低 1 行ずつ存在
- Phase 1-2 の列に hotspot `[?]` が残っていない

いずれか欠けたら `BLOCK` を返し、足りない箇所を列挙。

## Output format

```
## ✖不整合 (auto-detected by sheet formulas)
- [row 12] BUC 関連オブジェクト2: 情報「請求書マスタ」がどのシートにも存在しない

## Orphans
- アクター '暫定管理者' — 定義されているが BUC 関連オブジェクト1/2 から未参照
- 情報 '取引履歴' — 同上

## Anti-patterns
- [#2] 情報 'customer_master' は DB テーブル命名規則。ビジネス名に置換を推奨
- [#3] 条件 '金額が null でない' は実装ルール。条件から除外を推奨

## Phase 2 gate: BLOCK
  理由: BUC 行 5 の UC 'XXXを確定する' に アクター relation が未設定
```

## Write behavior

**None.** このスキルは読み取り専用。修正は `rdra-ingest` / `rdra-review` が担当。

## Non-goals

- 差分適用 → `rdra-ingest`
- 修正案提示 → `rdra-review`
- 新規立ち上げ → `rdra-setup`
