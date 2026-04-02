# 次元1: 環境再現性

「`git clone` → 1コマンド」で開発環境が立つか。"Works on my machine" を排除する。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| 環境定義ファイルが存在する | `flake.nix`, `.devcontainer/devcontainer.json`, `mise.toml`, `.tool-versions`, `shell.nix`, `default.nix` のいずれかが存在 | 1つ以上存在 |
| Lock ファイルがコミットされている | `flake.lock`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `poetry.lock`, `Gemfile.lock`, `go.sum` を git tracked で検出 | 該当するlock fileがすべて tracked |
| セットアップ手順が文書化されている | `README.md` に "install", "setup", "getting started", "development" セクションが存在 | セクションが存在し空でない |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Nix Flakes で環境定義 | `flake.nix` に `devShells` または `devShell` が定義 | 定義あり |
| CI と同一の環境定義を使用 | CI workflow 内で `nix develop`, `devcontainer`, `mise` 等の参照 | 参照あり |
| 環境のバリデーション | `nix flake check`, `devcontainer build --no-cache` 等がCI/hookで実行 | 実行設定あり |
| `.envrc` / direnv 統合 | `.envrc` が存在し `use flake` or `use nix` を含む | 存在+内容一致 |

## ツール（再現性レベル順）

| ツール | 再現性 | 特徴 |
|--------|--------|------|
| **Nix Flakes** | 最高 | 密閉評価、明示的入力、`flake.lock`で全固定 |
| **devenv / devbox** | 高 | Nix ベースだがUXがフレンドリー |
| **devcontainer** | 中〜高 | `.devcontainer/` spec、VS Code/Codespaces/Gitpod対応 |
| **mise** | 中 | `.mise.toml` でツールバージョン管理（node, python等） |
| **asdf** | 中 | `.tool-versions`、プラグインベース |
| **Lock files のみ** | 低 | 必要だが十分ではない |

## 判定基準

| スコア | 条件 |
|--------|------|
| A | Nix Flakes or devcontainer + lock files committed + CI同一環境 + direnv統合 |
| B | 環境定義ファイル存在 + lock files committed + セットアップ文書化 |
| C | lock files は committed だが環境定義ファイルが不完全、またはセットアップ文書なし |
| F | 環境定義ファイルなし、またはlock filesが未コミット |
