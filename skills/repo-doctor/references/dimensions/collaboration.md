# 次元9: コラボレーション

PRプロセス、レビュー体制、コミット規約が整備されているか。

## 検出チェック

### 必須項目（Small以上）

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| コミットメッセージ規約がある | `commitlint.config.js`, `.czrc`, `cz.toml`, CONTRIBUTING.md 内の規約記述 | 規約が定義されている |
| PR テンプレートが存在（Medium以上） | `.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md` | 存在 |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Conventional Commits 準拠 | commitlint 設定で `@commitlint/config-conventional` 使用、または git log で `feat:`, `fix:` パターンの一貫性 | 準拠 |
| CODEOWNERS が設定（Large） | `.github/CODEOWNERS`, `CODEOWNERS` | 存在 |
| Branch protection が有効 | `.github/settings.yml` (probot-settings), または GitHub API で確認 | 設定あり |
| Issue テンプレートが存在 | `.github/ISSUE_TEMPLATE/` ディレクトリ | 存在 + 1テンプレート以上 |
| 自動 changelog 生成 | `git-cliff.toml`, `.cliff.toml`, `release.config.js` (semantic-release), `cliff.toml` | 設定あり |
| PR サイズの制限/ガイドライン | PR テンプレートに"small PRs"のガイド、または danger/PR size check | 設定あり |
| 自動レビュアー割り当て | CODEOWNERS, GitHub review assignment | 設定あり |

## Conventional Commits

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

| type | 用途 |
|------|------|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `chore` | ビルド/ツール変更 |
| `docs` | ドキュメント |
| `refactor` | リファクタリング |
| `test` | テスト追加/修正 |
| `perf` | パフォーマンス改善 |
| `ci` | CI設定変更 |

**利点:** 自動changelog生成、semantic versioning の自動判定、git log の可読性

## ツール

| ツール | 用途 | 特徴 |
|--------|------|------|
| **commitlint** | コミットメッセージ検証 | `prek` / `lefthook` / `husky` と統合。conventional commits 準拠チェック |
| **git-cliff** | Changelog 生成 | Rust製、高速。conventional commits からchangelog自動生成 |
| **semantic-release** | バージョニング+リリース | conventional commits からバージョン判定、changelog、npm publish |
| **danger** | PRレビュー自動化 | PRサイズ警告、changelog更新チェック等 |

## PRプロセスのベストプラクティス

- **PRサイズ**: 400行以下。大きいPRはレビュー品質が低下する
- **PR テンプレート**: Summary + Test Plan + Checklist 構造
- **CODEOWNERS**: ファイルパスごとにドメインエキスパートを自動アサイン
- **Branch protection**: レビュー必須 + CI pass 必須 + branch up-to-date 必須
- **Stacked PRs**: 大きな変更はstacked PRsで分割（Graphite等）

## 判定基準

| スコア | 条件 |
|--------|------|
| A | Conventional Commits + PR template + CODEOWNERS + branch protection + changelog自動生成 |
| B | コミット規約あり + PR template（Medium+） |
| C | コミット規約が不統一、またはPR template未設定（Medium+） |
| F | コミットメッセージが無規約（"fix stuff", "wip"が主流） |
