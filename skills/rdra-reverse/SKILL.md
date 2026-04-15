---
name: rdra-reverse
description: This skill should be used to reverse-engineer an existing system into the 9 RDRA source sheets. Follows the 8-step top-down (screens, external interfaces, DB schema → information, UCs, actors) + bottom-up (code folder structure) procedure from rdra.jp/既存システムの可視化. Accepts paths to codebase, DDL/migrations, screen lists, and external interface docs as inputs. Triggers on "既存システムを RDRA で可視化", "reverse engineer into RDRA", "この legacy コードを RDRA に起こす". Does NOT depend on the RDRAAgent0.7 external tool.
---

# rdra-reverse

既存システムを RDRA 9 ソースシートに逆写像する狭い入口。rdra.jp/既存システムの可視化 の 8 ステップ手順を Claude 単体で実装する (外部 CLI 非依存)。

## Shared context

- `../rdra-shared/methodology.md`
- `../rdra-shared/sheet-schema.md`
- `../rdra-shared/anti-patterns.md` — 特に #2 (DB テーブル ≠ 情報), #3 (実装ルールが条件に漏れる)
- `../rdra-shared/guardrails.md`

## Inputs (ask on first run)

1. Codebase path (ローカル or git URL)
2. DB schema source (DDL ファイル / migrations ディレクトリ / live 接続文字列)
3. Screen inventory (URL 一覧 / Figma / 画面定義書)
4. 外部インターフェース (API 仕様書, バッチ一覧, 連携ファイル定義)
5. Spreadsheet ID

`.rdra-config.toml` に保存。

## Workflow (8 steps)

### Top-down (信頼度の高い資料から先に)

1. **画面一覧整理** — 画面リストを機能単位で分類して整理。まずは list 化、シートにはまだ書かない
2. **画面 → UC 分類** — 各画面で何ができるかを `XをYする` 形式で命名 → `BUC` F 列の候補
3. **アクター関係抽出** — 各 UC の実行者を特定 → `アクター` シートに append。BUC の generic relation (G=アクター, H=該当名) で結線
4. **外部 IF 整理** — バッチ/API/連携ファイル → `外部システム` シートに append。BUC の generic relation (G=外部システム, H=該当名) で結線
5. **DB スキーマ → 情報洗出** — **ビジネスで管理されている ID 単位** のみ抽出 (anti-pattern #2)。例: `t_customer_master` から「顧客」という情報を抽出するが、`t_customer_master` 自体は情報にしない。`情報` シートの `コンテキスト` 列で業務単位にまとめる

### Cross-link

6. **情報 ↔ UC 関連付け** — 各 UC が参照/更新する情報を BUC の別 relation スロット (I/J 列 = 関連モデル2/関連オブジェクト2) に記入。アクター + 情報の 2 軸が必要な UC は G-J の両方を使う。3 軸以上は同じ UC を複数行に分ける
7. **状態遷移特定** — 情報のライフサイクル (例: 申込 → 審査中 → 承認 → 発行) を抽出し、`状態` シートに append。`状態モデル` 列で情報シートと名前一致

### Bottom-up

8. **フォルダ構成インデックス** — ソースコードのモジュール構造を BUC/UC とマッピング。**この情報はシートには書かず、別途 `rdra-reverse-index.md` として保持**。後でコード変更が RDRA のどこに影響するか追跡するための補助資料

## 条件/バリエーションは後回し

Phase 3 相当。機能詳細 (if 分岐, enum, master table) から条件/バリエーション候補を収集するが:

- **実装制約** (null check, 文字列長, HTTP status) は除外 (anti-pattern #3)
- **ビジネスルール** (「金額 10 万以上は承認必須」) のみ採用

## Skill 連携

- 差分書き込みは `gws sheets` を直接呼ぶ (テンプレは `../rdra-shared/gws-operations.md`)
- 最終段階で必ず `rdra-check` を呼んで orphan / 不整合を確認
- 曖昧なものは全て hotspot `[?]` で温存 (落とさない)

## Non-goals

- 外部 CLI (RDRAAgent0.7 等) への委譲
- 新規プロジェクト → `rdra-setup`
- 議事録取り込み → `rdra-ingest`
