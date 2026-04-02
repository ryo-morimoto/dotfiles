# 次元4: 静的解析

バグ、anti-pattern、スタイル不統一をコード実行前に検出する。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Linter が設定されている | 設定ファイル検出（後述のツール表参照） | スタックに対応するlinter設定が存在 |
| Formatter が設定されている | 設定ファイル検出 | スタックに対応するformatter設定が存在 |
| 設定が "warn" 放置でない | linter設定内の `warn` / `off` ルール数を `error` と比較 | `warn` がルール総数の30%未満 |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| 型チェッカーが strict モード | `tsconfig.json` に `strict: true`、`pyright` に `typeCheckingMode: strict` 等 | strict有効 |
| 複雑度チェック | `eslint`のcomplexity rule、`flake8-cognitive-complexity`、SonarQube等 | 閾値設定あり |
| 重複検知 | jscpd, PMD CPD, Semgrep duplicate rules | 設定あり |
| カスタムルール（Semgrep） | `.semgrep/`, `.semgrep.yml` の存在 | プロジェクト固有ルールあり |
| IDE 統合 | `.vscode/settings.json` or `.editorconfig` にlinter/formatter設定 | 設定あり |

## スタック別ツール

### JavaScript / TypeScript

| カテゴリ | ツール | 設定ファイル | 備考 |
|----------|--------|-------------|------|
| All-in-one | **Biome** | `biome.json`, `biome.jsonc` | lint + format。2025年以降のデファクト候補。型対応ルールあり (v2+) |
| Linter | **ESLint v9** | `eslint.config.js` (flat config) | エコシステム最大。プラグイン豊富 |
| Linter (高速) | **Oxlint** | `oxlintrc.json` | Rust製、ESLintの50-100x高速。695組み込みルール |
| Formatter | **Prettier** | `.prettierrc`, `prettier.config.js` | デファクト |
| Type checker | **tsc** | `tsconfig.json` | `strict: true` 必須 |

### Python

| カテゴリ | ツール | 設定ファイル | 備考 |
|----------|--------|-------------|------|
| All-in-one | **Ruff** | `ruff.toml`, `pyproject.toml [tool.ruff]` | flake8 + isort + black + pyflakes を単一Rustバイナリで置換 |
| Type checker | **Pyright** / **mypy** | `pyrightconfig.json`, `mypy.ini` | Pyright推奨（VS Code統合、高速） |

### Rust

| カテゴリ | ツール | 設定ファイル | 備考 |
|----------|--------|-------------|------|
| Linter | **Clippy** | `clippy.toml`, `.clippy.toml` | 公式lint。`-W clippy::pedantic` でより厳格に |
| Formatter | **rustfmt** | `rustfmt.toml`, `.rustfmt.toml` | 公式formatter |

### Nix

| カテゴリ | ツール | 設定ファイル | 備考 |
|----------|--------|-------------|------|
| Linter | **statix** | - | anti-pattern 検出 |
| Formatter | **nixfmt** | - | 公式formatter |
| Dead code | **deadnix** | - | 未使用バインディング検出 |

### Go

| カテゴリ | ツール | 設定ファイル | 備考 |
|----------|--------|-------------|------|
| Linter | **golangci-lint** | `.golangci.yml` | 複数linterの統合実行 |
| Formatter | **gofmt** / **goimports** | - | 公式 |

### 言語横断

| ツール | 用途 | 備考 |
|--------|------|------|
| **Semgrep** | カスタムSAST rules | プロジェクト固有のanti-pattern検出。`p/owasp-top-ten` 等のルールセット |
| **SonarQube** / **SonarCloud** | 25+ quality model | 複雑度、重複、セキュリティ、code smells |
| **EditorConfig** | IDE横断のフォーマット設定 | `.editorconfig` |

## アンチパターン

- **全ルール `warn`** — 誰も警告を読まない。errorにするか無効化する
- **IDE/hook/CI で異なる設定** — 「ローカルでは通るがCIで落ちる」問題
- **linter disable コメントの氾濫** — `eslint-disable`, `# noqa` が10件以上は構造的問題の兆候

## 判定基準

| スコア | 条件 |
|--------|------|
| A | linter + formatter + 型チェッカー(strict) + 複雑度チェック + IDE統合 |
| B | linter + formatter + 型チェッカー設定済み、warn放置なし |
| C | linter or formatter のみ、または設定はあるがwarn放置が多い |
| F | 静的解析ツール未設定 |
