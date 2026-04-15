# gws Operations Cheatsheet for RDRA Sheets

全 RDRA skill はこのファイルの 4 テンプレを使って `gws` を直接呼ぶ。Python wrapper は持たない (YAGNI)。

## 前提

- `gws` (Google Workspace CLI) は nix で install 済み、認証セットアップ済み
- stdout に JSON、stderr に `Using keyring backend: keyring` のノイズ 1 行 (無視してよい)
- 実行前に **必ず** `../rdra-shared/guardrails.md` の allowlist を確認し、書き込み先が source 9 シートであることを agent 側でチェックする

## 1. タブ一覧を取る

```bash
gws sheets spreadsheets get \
  --params '{"spreadsheetId": "<ID>", "fields": "sheets.properties(title,index)"}' \
  --format json
```

返り値 (抜粋):
```json
{"sheets":[{"properties":{"index":0,"title":"参照設定"}}, ...]}
```

## 2. セル範囲を読む

```bash
gws sheets spreadsheets values get \
  --params '{"spreadsheetId": "<ID>", "range": "情報!A1:G100"}' \
  --format json
```

- `range` は A1 記法。シート名に特殊文字 (`✖`, `■`) があるときはシングルクォートで囲む: `"'✖不整合'!A1:F50"`
- 返り値: `{"range":"...","majorDimension":"ROWS","values":[[...],[...]]}`

## 3. 行を append

```bash
gws sheets spreadsheets values append \
  --params '{"spreadsheetId":"<ID>","range":"<sheet>","valueInputOption":"USER_ENTERED","insertDataOption":"INSERT_ROWS"}' \
  --json '{"values":[["cell1","cell2","cell3"],["cell1","cell2","cell3"]]}' \
  --format json
```

- `range` はシート名のみで OK (テーブル末尾を自動検出して追記する)
- `valueInputOption`: `USER_ENTERED` (数式も解釈) / `RAW` (文字列そのまま)
- `insertDataOption`: `INSERT_ROWS` (間に挿入) / `OVERWRITE` (既存行を上書き)

## 4. 指定範囲を update

```bash
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"<ID>","range":"情報!B5:G5","valueInputOption":"USER_ENTERED"}' \
  --json '{"values":[["v1","v2","v3","v4","v5","v6"]]}' \
  --format json
```

- 単一セル / 範囲 / 複数行いずれも可
- 行数 × 列数が `values` の shape と一致すること

## Pre-call checklist (Claude が呼ぶ前に)

1. `<sheet>` は source 9 シート (`アクター` / `外部システム` / `情報` / `状態` / `BUC` / `条件` / `バリエーション` / `機能要求` / `非機能要求`) のいずれかか？
2. 派生タブ (`✖不整合` / `UC_PIVOT` / `■関連データ` / `ZeroOne`) や分析タブ (`参照設定` / `分析準備` / `関連WK` / `モデル分析準備` / `情報分析` / `状態分析` / `条件分析`) を書き込み対象にしていないか？
3. BUC の `関連オブジェクト1/2` を書くなら、対応するシートにその名前が実在するか (read で確認)？
4. 条件シートに実装ルール (`null`, `length`, `HTTP`, `timeout`) を含んでいないか？

いずれか NG なら呼び出さず、ユーザに理由を説明する (`../rdra-shared/anti-patterns.md` 参照)。

## エラー時の復旧

- gws が非 0 を返したら stderr をそのまま報告
- 認証切れの兆候なら「`gws` の認証が切れている可能性があります」とユーザに伝える (手動再認証が必要)
- API レート制限 (HTTP 429) は指数バックオフでリトライ可能だが、agent が自動リトライせず 1 回で失敗報告する方が安全
