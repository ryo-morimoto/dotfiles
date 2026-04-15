---
name: rdra-ingest
description: This skill should be used to reflect meeting notes into the RDRA Google Sheet. Accepts a markdown/text file path containing Slack huddle transcripts, Notta exports, Google Meet summaries, or generic meeting notes. Extracts candidates for the 9 RDRA source sheets (アクター / 外部システム / 情報 / 状態 / BUC / 条件 / バリエーション / 機能要求 / 非機能要求); matches them against existing sheet rows by name; proposes a per-sheet diff; writes only after user approval. Triggers on "議事録を RDRA に", "meeting notes to RDRA", "この議事録を反映". Never writes directly to derived tabs.
---

# rdra-ingest

会議後に議事録を RDRA シートへ反映する狭い入口。

## Shared context

- `../rdra-shared/methodology.md`
- `../rdra-shared/sheet-schema.md`
- `../rdra-shared/guardrails.md`
- `../rdra-shared/anti-patterns.md` (特に #6 アクタードリフト, #7 参照 UC 爆発)

## Inputs

1. 議事録ファイルパス (`.md` / `.txt` / transcript)
2. Spreadsheet ID (`.rdra-config.toml` から)

## Workflow

### Step 1: Parse

議事録を読んで以下に分類:

| 分類 | 兆候 | 行き先シート |
|---|---|---|
| アクター候補 | 「営業が」「管理者は」 | `アクター` |
| 外部システム候補 | 「決済サービス」「SAP から」 | `外部システム` |
| BUC 候補 | 「請求業務」「月次締め」 | `BUC` (A-B 列 業務/BUC) |
| UC 候補 | 「〜を承認する」「〜を登録する」(`XをYする` 形式) | `BUC` (D アクティビティ, F UC) |
| 情報候補 | 「請求書 ID」「顧客番号」(ID で管理されるもの) | `情報` |
| 状態候補 | 「下書き → 承認待ち → 承認済」 | `状態` |
| 条件候補 | 「金額が 10 万以上のとき」 | `条件` |
| バリエーション候補 | 「個人/法人」「国内/海外」 | `バリエーション` |
| 機能要求候補 | 「〜できるようにしたい」「〜を表示したい」 | `機能要求` (アクター紐付け必須) |
| 非機能要求候補 | 「応答は 1 秒以内」「ログは 1 年保持」 | `非機能要求` (検証方法も抽出) |

### Step 2: Match against existing sheet

`gws sheets spreadsheets values get` (`../rdra-shared/gws-operations.md` §2) で 9 ソースシート全体を取得し、候補を既存行と照合:

- **完全一致** → 既存行として扱う (必要なら update 候補)
- **部分一致/表記揺れ** → hotspot `[?]` 付きで新規提案 + アクタードリフト (anti-pattern #6) の可能性をユーザに確認
- **未知** → 新規 append 候補

### Step 3: Anti-pattern guard

提案する前に以下を検査:

- 参照系 UC 候補が 5 個を超えていないか (anti-pattern #7)
- 情報候補に DB テーブル名そのものが混ざっていないか (anti-pattern #2)
- 条件候補に実装ルール文言 (`null`, `length`, `HTTP`, `timeout`) が混ざっていないか (anti-pattern #3)
- アクター名の表記揺れ (anti-pattern #6)

引っかかった候補は refuse または hotspot に格下げ。

### Step 4: Propose diff

per-sheet 差分を表形式で提示してユーザ承認を待つ:

```
シート: アクター
  + 経理担当者 (new)
  ~ 営業部 → 営業担当 (rename; affects BUC 関連オブジェクト refs in rows 3, 7, 12)

シート: BUC
  + row N: 業務=経理, BUC=月次締め [?], UC=請求書を承認する, 関連モデル1=アクター, 関連オブジェクト1=経理担当者
```

### Step 5: Apply

承認された差分のみ `gws sheets spreadsheets values append` / `update` (テンプレは `../rdra-shared/gws-operations.md`) で適用。書き込み前に `../rdra-shared/guardrails.md` の allowlist チェックを通す。

### Step 6: Recheck

書き込み後、`gws sheets spreadsheets values get` で `'✖不整合'` タブ (シングルクォート必須) を読む。新規不整合が増えていたら警告し、revert 提案。

## Non-goals

- Slack/Notta/Meet からの **直接取得** (入力は常にファイルパス。取得は別 skill / 別ツールの仕事)
- 新規立ち上げ → `rdra-setup`
- 単独の整合チェック → `rdra-check`
