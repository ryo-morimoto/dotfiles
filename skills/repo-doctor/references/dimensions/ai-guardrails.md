# 次元11: AI ガードレール

AI agentがコードを生成する時代に、品質・アーキテクチャ・セキュリティを維持するための追加的な防御層。

## 背景: なぜ専用のガードレールが必要か

研究データ（"Debt Behind the AI Boom", 2026年3月, arxiv.org/html/2603.28592v1）:

- 304,362件のAI生成コミットを分析 → 15%以上が静的解析issueを導入
- AI導入issueの **24.2% がHEADに残存**（修正されない）
- セキュリティissueは **41.1%** が残存（最も高い残存率）
- AI生成コードは **1.7x多い論理/正当性バグ**

OX Security報告（2025年10月）: 10の頻出anti-pattern
- 過剰コメント (90-100%)
- 教科書的すぎる実装 (80-90%)
- 過剰な抽象化 (80-90%)
- リファクタリング回避 (80-90%)
- 偽テストカバレッジ (40-50%)
- プロジェクト規約無視 (40-50%)

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| AI agent 向け指示ファイルが存在 | `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `.cursorrules`, `.cursor/rules/` | 1つ以上存在し、内容が実質的（10行以上） |
| 他の次元（1-10）で B 以上の防御層がある | 次元3(Git Hooks) + 次元4(静的解析) + 次元8(CI/CD) の評価 | 3次元とも C 以上 |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| アーキテクチャ適合テスト | ArchUnit, eslint-plugin-boundaries, Semgrep custom rules でモジュール境界を強制 | テスト/ルールが存在 |
| Banned-API ルール | Ruff `TID251`, ESLint `no-restricted-imports`, Semgrep pattern rules | プロジェクト固有のラッパーへの誘導ルールあり |
| 重複検知がCIで実行 | jscpd, PMD CPD, Semgrep duplicate detection | CI実行あり |
| Agent指示が定期的に更新されている | CLAUDE.md/AGENTS.md の最終更新日（git log） | 直近3ヶ月以内に更新 |
| 多段レビュー体制 | CodeRabbit, CodeScene PR review, Graphite Agent 等のAIレビューツール + 人間レビュー | 設定あり |
| エラーハンドリング完全性チェック | Ruff `BLE001`, `TRY003`, ESLint `@typescript-eslint/no-floating-promises`, Semgrep catch rules | ルールが有効 |

## 4層防御モデル（AI時代）

Chris Richardson "GenAI Development Platform" (2026年3月) より:

```
Layer 1: Agent-side skill/checklist
  └─ エージェント自身がコード生成時に品質チェック
     CLAUDE.md, CodeScene MCP, self-reflection パターン

Layer 2: Pre-commit git hook（決定論的）
  └─ Gitleaks + linter + formatter + type check
     「Claude Code skillと異なり、決定論的である」

Layer 3: CI/CD pipeline
  └─ テスト + SAST + SCA + 全ファイルスキャン

Layer 4: Automated PR review
  └─ CodeRabbit/CodeScene/Graphite Agent + 人間レビュー
     Quality Gate でブロック
```

**原則**: 1層が突破されても他が捕捉する。Agent指示（非決定論的）だけに依存しない。

## Agent指示ファイルの品質チェック

`CLAUDE.md` / `AGENTS.md` の内容品質：

| チェック | 良い例 | 悪い例 |
|----------|--------|--------|
| プロジェクトの WHY が書かれている | 「このリポジトリは...のために存在する」 | 概要なし |
| スタックと構造の WHAT | 「TypeScript + Hono, src/routes にルーティング」 | なし |
| 開発ワークフローの HOW | 「`nix develop` → `npm test` → `npm run build`」 | なし |
| linterで対応可能なスタイルガイドを含めていない | linter/formatterに委ねている | 「インデントは2スペース」等をCLAUDE.mdに書いている |
| 300行以下 | 簡潔 | 1000行のCLAUDE.md |

## アーキテクチャ適合テストの例

### ESLint (eslint-plugin-boundaries)
```js
// 「domain層がinfra層をimportしてはならない」
rules: {
  'boundaries/element-types': [2, {
    default: 'disallow',
    rules: [
      { from: 'domain', allow: ['domain'] },
      { from: 'application', allow: ['domain', 'application'] },
      { from: 'infrastructure', allow: ['domain', 'application', 'infrastructure'] },
    ]
  }]
}
```

### Semgrep (custom rule)
```yaml
rules:
  - id: no-direct-db-in-handler
    pattern: |
      import { db } from "..."
    paths:
      include: ["src/handlers/**"]
    message: "Handlers must not import db directly. Use repository layer."
    severity: ERROR
```

## 判定基準

| スコア | 条件 |
|--------|------|
| A | Agent指示ファイル(実質的) + アーキテクチャ適合テスト + banned-API + 重複検知 + 多段レビュー |
| B | Agent指示ファイル(実質的) + 他の防御層(次元3,4,8)が全てB以上 |
| C | Agent指示ファイルが存在するが薄い、または他の防御層が不十分 |
| F | Agent指示ファイルなし + 防御層が脆弱 |
