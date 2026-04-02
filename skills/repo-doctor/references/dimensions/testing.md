# 次元6: テスト

テストが存在し、実際にバグを捕捉できるか。カバレッジ数値だけでなくテストの質を診る。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| テストファイルが存在する | `*.test.ts`, `*.spec.ts`, `*_test.go`, `*_test.rs`, `test_*.py`, `*_test.py`, `spec/**/*.rb` 等をGlob | 1ファイル以上存在 |
| テスト実行コマンドが定義されている | `package.json` の `scripts.test`, `Makefile` の `test` ターゲット, `Cargo.toml` (implicit), `pytest.ini`, `.github/workflows/` 内のtest実行 | 定義あり |
| テストがCIで実行されている | CI workflow内でテスト実行コマンドの参照 | 参照あり |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| カバレッジ測定が設定されている | `jest.config` の `coverageThreshold`, `pytest-cov`, `tarpaulin`, `c8`, `istanbul`, Codecov/Coveralls設定 | 設定あり |
| カバレッジ閾値が設定されている | 設定ファイル内の閾値定義 | 閾値が明示されている（60%以上推奨） |
| テストピラミッド構造 | unit + integration (+ e2e) の各層にテストが存在 | 2層以上 |
| Mutation testing が導入されている | Stryker (`stryker.conf.js`), cargo-mutants, mutant (Ruby), PIT | 設定あり |
| Property-based testing を使用 | fast-check, Hypothesis, proptest, quickcheck のimport | import存在 |
| Flaky test 管理 | quarantine ディレクトリ、skip + issue リンク、BuildPulse/Trunk設定 | 管理プロセスあり |
| PR ごとのカバレッジ diff | Codecov, Coveralls の PR コメント設定 | 設定あり |

## テストピラミッド

```
        /  E2E  \        5-10%   Playwright, Cypress
       / Integration \    20-30%  API tests, DB tests
      /    Unit Tests  \  60-70%  vitest, jest, pytest
```

- **Unit**: 純粋関数、ビジネスロジック。高速・決定論的
- **Integration**: DB接続、API呼び出し、ファイルI/O。外部依存あり
- **E2E**: ユーザーフロー全体。最も遅く脆い

## スタック別テストツール

| スタック | Unit/Integration | E2E | Coverage | Mutation |
|----------|-----------------|-----|----------|----------|
| **JS/TS** | Vitest, Jest | Playwright | c8, istanbul | Stryker |
| **Rust** | cargo test | - | cargo-tarpaulin | cargo-mutants |
| **Python** | pytest | Playwright | pytest-cov | mutmut |
| **Go** | go test | - | go test -cover | go-mutesting |
| **Ruby** | RSpec, Minitest | Capybara | SimpleCov | Mutant |

## カバレッジの考え方

- **最低ライン**: 60-70% line coverage（大きな未テスト領域を防ぐ）
- **目標**: 80%+ line coverage + branch coverage 追跡
- **重要**: PR単位のカバレッジdiff — 新規コードは閾値を満たすべき（全体が低くても）
- **罠**: 100%目標 → getter/setter のテスト、assert なしのテスト（カバレッジ詐欺）
- **本質**: mutation testing score > line coverage（テストが実際にバグを検出できるか）

## Mutation Testing

テストが実際にバグを検出できるかを検証する。コードに小さな変異（mutant）を注入し、テストが失敗するか確認。

- テストが失敗 → mutant killed（良い）
- テストが通る → mutant survived（テストが弱い）
- **目標**: クリティカルパスで mutation score 80%+

## 判定基準

| スコア | 条件 |
|--------|------|
| A | テストピラミッド(2層+) + カバレッジ閾値(70%+) + mutation testing + PRカバレッジdiff |
| B | テスト存在 + CI実行 + カバレッジ測定(60%+) |
| C | テスト存在 + CI実行だがカバレッジ未測定、またはカバレッジ < 60% |
| F | テストなし、またはテストがCIで実行されていない |
