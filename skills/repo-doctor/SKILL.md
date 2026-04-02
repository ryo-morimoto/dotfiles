---
name: repo-doctor
description: >
  リポジトリの健全性を11次元で網羅的に診断し、技術負債の蓄積を防ぐ環境整備ができているかチェックするスキル。
  agentic coding時代に爆発的にコードが増える状況で、CI・pre-commit・テスト・セキュリティ・構造・
  AI ガードレール等が適切に整備されているかを監査し、重大度付きの改善推奨を出力する。
  Activates when: "repo-doctor", "リポジトリ診断", "リポ健全性", "コード品質チェック",
  "技術負債チェック", "CI整備できてる？", "pre-commit入ってる？", "セキュリティスキャン",
  "テストカバレッジ足りてる？", "開発環境の整備状況", "repository health check",
  "code quality audit", "tech debt assessment", or when onboarding to a new repository
  and wanting to understand its quality infrastructure maturity.
---

# Repo Doctor

リポジトリの品質基盤を11次元で診断し、健全性レポートを出力する。

## 診断の核心原則

1. **決定論的メカニズムが主、エージェント指示は補助** — linter/型チェッカー/テスト/CIが強制層。CLAUDE.md/AGENTS.mdはガイダンスに過ぎない
2. **防御の多層化** — IDE→pre-commit→CI→PRレビューの4層。1層が突破されても他が捕捉する
3. **スナップショットよりトレンド** — 今の状態だけでなく、健全性が改善傾向か悪化傾向かを見る
4. **プロジェクト特性に応じた判断** — 個人ツールとプロダクションサービスでは要求水準が異なる

## ワークフロー

### Phase 0: プロジェクト特性の検出

診断基準はプロジェクト特性で変わる。まず以下を自動検出する：

**スタック検出（ファイル存在チェック）:**

| ファイル | 検出結果 |
|----------|----------|
| `flake.nix` | Nix Flakes |
| `package.json` | Node.js/JS/TS |
| `Cargo.toml` | Rust |
| `pyproject.toml` / `setup.py` | Python |
| `go.mod` | Go |
| `Gemfile` | Ruby |
| `*.csproj` / `*.sln` | .NET |

**規模検出:**

```bash
# ファイル数（テスト・生成物除く）
fd -e ts -e tsx -e js -e jsx -e rs -e py -e rb -e go -e nix --exclude node_modules --exclude target --exclude dist | wc -l
# LOC概算
tokei --compact 2>/dev/null || cloc --quiet --csv 2>/dev/null
```

**規模分類:**

| 分類 | 目安 | 診断の厳しさ |
|------|------|-------------|
| **Tiny** | ~500 LOC, 個人ツール | 最低限（環境再現性 + lint + fmt） |
| **Small** | ~5,000 LOC | 基本（+ テスト + git hooks） |
| **Medium** | ~50,000 LOC | 標準（全11次元） |
| **Large** | 50,000+ LOC | 厳格（全11次元 + トレンド監視必須） |

**AskUserQuestion（自動検出できない場合のみ）:**

> このリポジトリの用途は？（個人ツール / OSS ライブラリ / プロダクションサービス / モノレポ）

### Phase 1: 11次元スキャン

各次元を並行で診断する。次元ごとの詳細チェック項目は `references/dimensions/` を参照。

| # | 次元 | reference | 主な検出対象 |
|---|------|-----------|-------------|
| 1 | 環境再現性 | `dimensions/reproducibility.md` | flake.nix, devcontainer, mise, lock files |
| 2 | ディレクトリ構造 | `dimensions/structure.md` | 規模に応じた分割、ADR、README |
| 3 | Git Hooks | `dimensions/git-hooks.md` | pre-commit/lefthook/husky, 実行速度 |
| 4 | 静的解析 | `dimensions/static-analysis.md` | linter/formatter/型チェッカー設定 |
| 5 | セキュリティ | `dimensions/security.md` | secret検知、SCA、SAST |
| 6 | テスト | `dimensions/testing.md` | ピラミッド構造、カバレッジ、mutation |
| 7 | Dead Code & 依存衛生 | `dimensions/dead-code.md` | 未使用コード/依存、更新自動化、ライセンス |
| 8 | CI/CD | `dimensions/ci-cd.md` | パイプライン構成、quality gate |
| 9 | コラボレーション | `dimensions/collaboration.md` | PR template, CODEOWNERS, conventional commits |
| 10 | 可観測性 | `dimensions/observability.md` | 複雑度/カバレッジのトレンド追跡 |
| 11 | AI ガードレール | `dimensions/ai-guardrails.md` | CLAUDE.md, AGENTS.md, アーキテクチャ適合テスト |

**各次元の診断手順:**

1. reference ファイルの「検出チェック」リストを実行（Glob/Grep/Read）
2. 検出結果を「充足 / 部分充足 / 未充足」に分類
3. スコアを算出（後述）

### Phase 2: スコアリング

各次元を **A / B / C / F** で評価する：

| スコア | 意味 | 基準 |
|--------|------|------|
| **A** | 優良 | 必須項目すべて充足 + 推奨項目の50%以上 |
| **B** | 良好 | 必須項目すべて充足 |
| **C** | 改善必要 | 必須項目の一部が未充足 |
| **F** | 未整備 | 必須項目の大半が未充足、またはその次元が完全に欠如 |

**プロジェクト規模による必須/推奨の切り替え:**

- Tiny: 次元1,4のみ必須。他は推奨
- Small: 次元1,2,3,4,6が必須。他は推奨
- Medium: 全次元が必須
- Large: 全次元が必須 + 推奨項目も一部必須に昇格

### Phase 3: レポート出力

以下の形式で出力する：

```markdown
# Repo Doctor Report

## サマリー

| 次元 | スコア | 最優先アクション |
|------|--------|-----------------|
| 環境再現性 | A | - |
| Git Hooks | C | gitleaks を pre-commit に追加 |
| テスト | F | テストファイルが存在しない |
| ... | ... | ... |

**総合判定:** B（11次元中 A:4 B:3 C:2 F:2）
**プロジェクト規模:** Medium
**検出スタック:** TypeScript (Node.js), Nix

## 改善ロードマップ

### 🔴 Critical（F評価の次元）
1. [具体的なアクション + 理由 + 推奨ツール]

### 🟡 Important（C評価の次元）
1. [具体的なアクション + 理由 + 推奨ツール]

### 🟢 Enhancement（B→A への改善）
1. [具体的なアクション]

## 次元別詳細
[各次元の検出結果と根拠]
```

### Phase 4: 改善実行（オプション）

ユーザーが改善実行を希望した場合：

1. ロードマップのCriticalから順に着手
2. 各改善はツールの導入設定を具体的に実装（設定ファイル生成、CI workflow追加等）
3. 1つの改善が完了するごとにユーザーに確認
4. ツール固有のAPIや設定は Context7 MCP で最新ドキュメントを取得してから実装

## 判断基準

**ツールを推奨するとき** → ツール名だけでなく、Context7 MCPで最新ドキュメントを確認し、プロジェクトのスタックに適合するか検証してから推奨する。`references/sources.md` に主要ツールのドキュメントURLを記載。

**スタック固有のツールを選ぶとき** → 以下の優先順位で判断：
1. プロジェクトに既に導入済みのツール（package.json, flake.nix等で検出）
2. そのエコシステムのデファクト（references内の推奨ツール）
3. クロスプラットフォーム汎用ツール

**診断が曖昧なとき** → 根拠を明示した上で「部分充足」とし、ユーザーに判断を委ねる。推測で「充足」にしない。
