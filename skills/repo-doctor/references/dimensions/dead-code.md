# 次元7: Dead Code & 依存衛生

コードベースを lean に保つ。すべてのコード行は負債。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| 未使用依存の検出手段がある | knip, depcheck, cargo-udeps, deadnix の設定/hookでの参照 | 1つ以上導入 |
| 依存更新の自動化 | `renovate.json`, `.github/dependabot.yml` の存在 | 設定あり |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| 未使用コード検出がCIで実行 | knip, deadnix, vulture 等のCI workflow参照 | CI実行あり |
| 未使用export検出（JS/TS） | knip の設定 | 設定あり |
| patch/minor の automerge | Renovate 設定で `automerge: true` on minor/patch | 設定あり |
| ライセンスコンプライアンス | FOSSA, license-checker, reuse-tool の設定 | 設定あり（OSS/商用プロダクトの場合） |
| SBOM 生成 | Syft, GitHub SBOM export | リリースフローに存在 |
| 依存更新のグルーピング | Renovate の group rules | 設定あり |

## ツール

### 未使用コード/依存

| ツール | エコシステム | 検出対象 |
|--------|-------------|----------|
| **Knip** | JS/TS | 未使用ファイル、export、依存、devDependencies、型 — 一括検出。Jest/Storybook/Vitest等の設定も理解 |
| **deadnix** | Nix | 未使用バインディング |
| **cargo-udeps** | Rust | 未使用依存 in Cargo.toml |
| **vulture** | Python | Dead code 検出 |
| **depcheck** | JS/TS | レガシー。Knipに移行推奨 |

### 依存更新

| ツール | 特徴 |
|--------|------|
| **Renovate** | 最も柔軟。グルーピング、automerge、カスタムマネージャー、self-hosted可 |
| **Dependabot** | GitHub native。設定最小。Renovateほど柔軟ではない |
| **npm-check-updates** | CLIでインタラクティブに更新 |

### ライセンス

| ツール | 特徴 |
|--------|------|
| **FOSSA** | 自動ライセンススキャン、深いtransitive deps分析 |
| **Syft** | SBOM生成（CycloneDX, SPDX形式） |
| **reuse** | FSFE標準。各ファイルにライセンスメタデータ |
| **license-checker** (npm) | CLI でnpm依存のライセンスチェック |

## アンチパターン

- **未使用dependenciesが10+** — `npm install` が遅くなり、攻撃面が増える
- **依存更新PR放置** — Renovate/DependabotのPRが数十件溜まっている
- **dead code コメントアウト** — 削除せずコメントアウトで残す（git historyがある）
- **`_unused` 変数の蓄積** — lintで検出すべき

## 判定基準

| スコア | 条件 |
|--------|------|
| A | 未使用コード/依存検出(CI) + 依存更新自動化(automerge) + ライセンスチェック |
| B | 未使用依存検出 + 依存更新自動化（Renovate or Dependabot） |
| C | 依存更新自動化のみ、または未使用検出のみ |
| F | 未使用検出なし + 依存更新自動化なし |
