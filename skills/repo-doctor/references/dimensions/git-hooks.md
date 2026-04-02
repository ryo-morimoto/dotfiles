# 次元3: Git Hooks

コミット時点で品質問題を捕捉する最初の防御層。高速・決定論的であることが前提。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Hook マネージャが設定されている | `.pre-commit-config.yaml`, `lefthook.yml`, `.husky/`, `.lintstagedrc`, `prek.toml` のいずれか | 1つ以上存在 |
| フォーマッタが hook で実行 | 設定ファイル内に formatter（prettier, biome, rustfmt, nixfmt, ruff format, gofmt等）の参照 | 参照あり |
| リンタが hook で実行 | 設定ファイル内に linter（eslint, oxlint, biome, clippy, statix, ruff, golangci-lint等）の参照 | 参照あり |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Secret 検知が hook で実行 | `gitleaks` の参照が hook 設定内に存在 | 参照あり |
| Dead code 検知が hook で実行 | `deadnix`, `knip`, `vulture`, `cargo-udeps` 等の参照 | 参照あり |
| 型チェックが hook で実行 | `tsc --noEmit`, `pyright`, `mypy` 等の参照 | 参照あり |
| コミットメッセージ検証 | `commitlint`, `cz` (commitizen) 等の参照 | 参照あり |
| staged files のみ対象 | `lint-staged`, lefthook の `glob`/`files` 設定、pre-commit の `files` filter | 設定あり |
| Hook がCIでも実行可能 | `pre-commit run --all-files` または同等コマンドがCI workflowに存在 | 存在 |

## ツール比較

| ツール | エコシステム | 並列実行 | 特徴 |
|--------|-------------|---------|------|
| **pre-commit** | Python（言語非依存hook） | ○ | 最大のhookエコシステム。隔離環境でhook実行 |
| **Lefthook** | Go バイナリ | ○（デフォルト） | Node.js不要。ポリグロット/モノレポ向き |
| **Husky** | Node.js | △（lint-staged経由） | JS/TSプロジェクトのデファクト。7M+ weekly DL |
| **prek** | - | - | このdotfilesリポジトリで使用中 |

## パフォーマンス基準

- **目標**: pre-commit hook の実行が **5秒以内**
- staged files のみを対象にすることで達成
- 全ファイルスキャンはCIに委ねる
- Hook が遅いと開発者が `--no-verify` で迂回する → 防御層が無効化

## Hook で実行すべきチェック（優先順）

1. **Format** — 決定論的、false positive なし、高速
2. **Lint** — anti-pattern 検出、修正提案あり
3. **Secret detection** — コミット前にブロック必須（漏洩後の対応コストが極大）
4. **Type check** — コンパイル通らないコードのプッシュ防止
5. **Dead code** — 不要コードの蓄積防止
6. **Commit message validation** — conventional commits 準拠

## 判定基準

| スコア | 条件 |
|--------|------|
| A | Hook マネージャ + fmt + lint + secrets + 型チェック + staged only + CI連携 |
| B | Hook マネージャ + fmt + lint が設定済み |
| C | Hook マネージャは存在するが設定が不完全（fmt or lint のみ） |
| F | Git hooks が未設定、または `.git/hooks/` に手動スクリプトのみ |
