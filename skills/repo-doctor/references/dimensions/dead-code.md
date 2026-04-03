# 次元7: Dead Code & 依存衛生

コードベースを lean に保つ。すべてのコード行は負債。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| 未使用コード/依存の検出手段がある | knip, depcheck, cargo-udeps, deadnix, vulture の設定/hook/CIでの参照 | 1つ以上導入 |
| 未使用コード/依存検出がlocalで実行できる | `just`, hook manager, package scripts, documented command から knip, deadnix, cargo-udeps, vulture を呼ぶ | local 実行パスあり |
| 未使用コード/依存検出がCI workflowで再確認される | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` 等に knip, deadnix, cargo-udeps, vulture の参照 | CI実行あり |
| 依存更新の自動化 | `renovate.json`, `.github/dependabot.yml` の存在 | 設定あり |
| 更新ポリシーに maturity gate がある | Renovate `minimumReleaseAge`, `pnpm-workspace.yaml`, `bunfig.toml` 等の参照 | 対応時は 7 日以上を設定 |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| 未使用コード検出がhook でも回る | hook manager から knip, deadnix, cargo-udeps, vulture を呼ぶ | fast path あり |
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
| **Renovate** | 最も柔軟。グルーピング、automerge、カスタムマネージャー、`minimumReleaseAge`、self-hosted可 |
| **Dependabot** | GitHub native。設定最小。Renovateほど柔軟ではない |
| **npm-check-updates** | CLIでインタラクティブに更新 |

**推奨戦略:** 依存更新PRの自動化だけでなく、package manager native の `minimumReleaseAge` 相当設定も併用する。Renovate の `minimumReleaseAge` は補完であり、package manager 側のガードの代替ではない。

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
- **dead code 検出がCI専用** — agent と開発者のフィードバックが遅く、修正ループが重くなる
- **dead code 検出がローカル専用** — mainline への流入を機械的に止められない
- **dead code コメントアウト** — 削除せずコメントアウトで残す（git historyがある）
- **`_unused` 変数の蓄積** — lintで検出すべき

## 判定基準

| スコア | 条件 |
|--------|------|
| A | 未使用コード/依存検出(local + CI) + hook fast path + 依存更新自動化(automerge) + maturity gate + ライセンスチェック |
| B | 未使用コード/依存検出(local + CI) + 依存更新自動化（Renovate or Dependabot） + maturity gate（対応時） |
| C | 未使用コード/依存の検出手段はあるが local または CI のどちらかが欠ける、または依存更新自動化のみ |
| F | 未使用コード/依存検出なし、または local 実行パスも dead-code CI workflow もない |
