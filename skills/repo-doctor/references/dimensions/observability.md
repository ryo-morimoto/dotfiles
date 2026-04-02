# 次元10: コード健全性の可観測性

スナップショットではなくトレンドを追跡する。コードベースが健全化しているか悪化しているかを可視化。

## 検出チェック

### 必須項目（Medium以上）

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| カバレッジトレンドの追跡 | Codecov, Coveralls, SonarCloud のCI統合 | 設定ありでPRにカバレッジ変化が表示される |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| コード品質ダッシュボード | SonarQube/SonarCloud, CodeClimate, CodeScene の設定 | 設定あり |
| 複雑度メトリクス追跡 | SonarQube cognitive complexity, CodeScene CodeHealth | 閾値設定あり |
| Quality Gate がPRをブロック | SonarCloud Quality Gate, CodeScene quality gate | merge ブロック設定あり |
| Tech debt 見積もり | SonarQube tech debt ratio, CodeScene hotspot analysis | メトリクス取得設定あり |
| Churn × Complexity 分析 | CodeScene（ファイル変更頻度 × 複雑度 = リスク） | 分析あり |

## 追跡すべきメトリクス

| メトリクス | 意味 | ツール |
|-----------|------|--------|
| **カバレッジトレンド** (モジュール別) | テスト網羅性の推移 | Codecov, Coveralls |
| **Cyclomatic/Cognitive complexity** | 変更ファイルの複雑度 | SonarQube, ESLint complexity rule |
| **Tech debt ratio** | 改修見積もり時間 / 開発時間 | SonarQube |
| **Churn × Complexity** | 頻繁に変更 × 複雑 = 最高リスク | CodeScene |
| **PRサイズ分布** | 大型化トレンド → レビュー品質低下 | GitHub API, Graphite |
| **Time to merge** | 長期化 → プロセス摩擦 | GitHub API |
| **Flaky test rate** | 増加 → テスト基盤の腐食 | BuildPulse, Trunk |

## CodeScene の知見

静的解析はスナップショットを見る。CodeScene は**時間軸**を考慮する：

- 複雑だが変更されないファイル → 低リスク
- 中程度の複雑度だが毎日変更されるファイル → 高リスク
- この「行動的コード解析」は International Conference on Technical Debt 2024 で best paper

**CodeHealth メトリクス**: 検証済み — 健全なコードは15x少ないバグ、2x速い開発、9x高いオンタイムデリバリー

## Small/Tiny プロジェクトでの代替

大規模ツール（SonarQube, CodeScene）は小規模プロジェクトにはオーバーキル。代替：

- **Codecov/Coveralls** — 無料プランあり。カバレッジトレンドの最低限
- **CI内でのメトリクス出力** — `tokei`/`cloc` でLOC推移、カバレッジ数値をCI artifactに保存
- **GitHub Insights** — Contributors, Code frequency, Network graph（組み込み・設定不要）

## 判定基準

| スコア | 条件 |
|--------|------|
| A | カバレッジトレンド + 品質ダッシュボード + Quality Gate + Churn×Complexity分析 |
| B | カバレッジトレンド追跡（Codecov等）+ Quality Gate |
| C | カバレッジ測定はあるがトレンド追跡なし |
| F | コード品質メトリクスの追跡なし |
