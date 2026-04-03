# 次元3: Git Hooks

コミット時点で品質問題を捕捉する最初の防御層。高速・決定論的であることが前提。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Hook マネージャが設定されている | `prek.toml`, `.pre-commit-config.yaml`, `lefthook.yml`, `.husky/`, `.lintstagedrc` のいずれか | 1つ以上存在 |
| フォーマッタが hook で実行 | 設定ファイル内に formatter（prettier, biome, rustfmt, nixfmt, ruff format, gofmt等）の参照 | 参照あり |
| リンタが hook で実行 | 設定ファイル内に linter（eslint, oxlint, biome, clippy, statix, ruff, golangci-lint等）の参照 | 参照あり |
| 同じ主要チェックを手動 local 実行できる | `just`, package scripts, documented command から fmt/lint/type/secrets を実行できる | commit を作らず再現可能 |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Secret 検知が hook で実行 | `gitleaks` の参照が hook 設定内に存在 | 参照あり |
| Dead code 検知が hook で実行 | `deadnix`, `knip`, `vulture`, `cargo-udeps` 等の参照 | 参照あり |
| 型チェックが hook で実行 | `tsc --noEmit`, `pyright`, `mypy` 等の参照 | 参照あり |
| コミットメッセージ検証 | `commitlint`, `cz` (commitizen) 等の参照 | 参照あり |
| staged files のみ対象 | `lint-staged`, lefthook の `glob`/`files` 設定、pre-commit の `files` filter | 設定あり |
| Hook チェックがCIでも再確認される | `pre-commit run --all-files` または同等コマンドがCI workflowに存在 | 存在 |
| hook / local / CI 共有コマンドが `just` に抽出 | `justfile` / `Justfile` が存在し、hook や CI から `just <recipe>` を呼ぶ | 30文字超の共有コマンドが recipe 化 |

## ツール比較

| ツール | エコシステム | 並列実行 | 特徴 |
|--------|-------------|---------|------|
| **prek** | Rust バイナリ | ○ | Repo Doctor の既定推奨。pre-commit 互換 hook 資産を流用しやすく、workspace 運用にも向く |
| **Lefthook** | Go バイナリ | ○（デフォルト） | Node.js不要。ポリグロット/モノレポ向き |
| **pre-commit** | Python（言語非依存hook） | ○ | 最大のhookエコシステム。既存資産が厚い場合の有力候補 |
| **Husky** | Node.js | △（lint-staged経由） | JS/TSプロジェクトのデファクト。7M+ weekly DL |

## パフォーマンス基準

- **目標**: pre-commit hook の実行が **5秒以内**
- staged files のみを対象にすることで達成
- commit 前は高速な subset、手動 local では full run、CI では再確認と重い全体スキャンを担う
- hook とCIで同じ長いコマンドを呼ぶ場合は `just` recipe に寄せる
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
| A | Hook マネージャ + fmt + lint + local 手動実行パス + secrets + 型チェック + staged only + CI再確認 + `just` 抽出（該当時） |
| B | Hook マネージャ + fmt + lint + local 手動実行パス が設定済み |
| C | Hook マネージャは存在するが local 手動実行パスが弱い、または fmt/lint のみ |
| F | Git hooks が未設定、または `.git/hooks/` に手動スクリプトのみ |
