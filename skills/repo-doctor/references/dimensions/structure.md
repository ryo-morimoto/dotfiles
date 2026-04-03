# 次元2: ディレクトリ構造 & Living Documentation

`tree --gitignore` で見たときに構造が明瞭か。規模・特性・言語に対して過不足がないか。設計意図が生きた形で残っているか。

## 参照resource

- `references/structure-patterns.md` — 言語/アプリ特性ごとの構造パターンと評価基準
- `references/living-documentation.md` — 設計意図の保持と鮮度評価、改善手段

## 診断手順

1. `tree --gitignore -L 4` を基本に、top-level と主要 subtree の責務が説明できるか確認する
2. 言語・アプリ種別・想定規模を検出し、`structure-patterns.md` のパターンに照合する
3. `README.md`, `ARCHITECTURE.md`, `docs/`, `AGENTS.md`, `CONTRIBUTING.md` などから、構造ルールが明示されているか確認する
4. living documentation の仕組み（ADR, architecture docs, content model, reusable docs, generated reference 等）を確認する
5. `living-documentation.md` の手順で関連ドキュメント候補から最も古い5ファイルを読み、対応するコード/パス/機能がまだ存在するか確認する

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| `tree --gitignore` 上で top-level 責務が明瞭 | `tree --gitignore -L 4` の出力を読み、top-level ディレクトリ名だけで責務が説明できるか確認 | 説明可能 |
| 構造が言語/アプリ特性/規模に適合 | `structure-patterns.md` のパターンに照合し、デファクトまたは明示ルールに一致 | 一致または合理的な custom pattern |
| README.md が存在し実質的内容がある | `README.md` の行数 > 10、"TODO" だけでない | 内容あり |
| エントリポイントが明確 | `main.ts`, `index.ts`, `main.rs`, `main.go`, `app.py` 等、またはビルド設定から特定可能 | 特定可能 |
| 設計意図を残す living documentation の仕組みがある | `docs/adr/`, `docs/decisions/`, `ARCHITECTURE.md`, `docs/architecture/`, `routes.ts`, workspace config, generated reference docs など | 少なくとも1系統存在 |
| 最も古い5件の関連ドキュメントに重大な drift がない | `living-documentation.md` の oldest-5 サンプリング | code/docs orphan がない |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| ADR（Architecture Decision Records）が存在 | `docs/decisions/`, `docs/adr/`, `docs/decision-record/`, `adr/` のいずれか | ディレクトリ存在 + 1件以上 |
| CONTRIBUTING.md が存在 | ファイル存在チェック | 存在 |
| テストとソースの分離規約が明確 | テストが `__tests__/`, `tests/`, `spec/`, `*_test.go`, `*_test.rs` 等の規約に従っている | 規約が一貫している |
| モジュール境界が自動検証される | dependency-cruiser, Nx module boundaries, ESLint `no-restricted-imports`, import-linter 等 | lint/conformance あり |
| docs lint / validation が local + CI で実行 | markdownlint, content linter, Vale, custom docs check 等 | local + CI 実行あり |
| reusable / single-source docs がある | reusable content, versioned docs, generated reference, `_AGENTS.md` 単一ソース等 | 同期漏れ防止策あり |
| durable な architecture docs がある | C4 context/container/component, arc42, ADR など | 低レベル実装断面に寄りすぎない |
| GitHub Community Health Files | `LICENSE`, `CODE_OF_CONDUCT.md`, `SECURITY.md` | 存在 |

## 重要な評価原則

- **デファクト優先**: まず言語/フレームワークの標準構造に従っているかを見る
- **custom pattern 許容**: 独自構造でも、どこかにルールが明示されていて `tree --gitignore` がそれに一致するなら高評価可能
- **過剰設計を減点**: Tiny/Small で DDD / monorepo / 過度な layering は減点
- **将来規模を考慮**: Large 想定や multi-app / multi-package の場合は monorepo / workspace / bounded context を加点
- **living docs は存在だけでなく鮮度を見る**: docs があるだけでは不十分。古い docs と現在コードの対応が取れているかを重視する

## 判定基準

| スコア | 条件 |
|--------|------|
| A | `tree --gitignore` が明瞭 + 規模/特性/言語に構造が適合 + living documentation の仕組みあり + oldest-5 サンプルが現行コードと整合 + 境界検証あり |
| B | 構造が概ね明瞭 + 規模/特性/言語に適合 + README/構造ルールあり + design intent を残す docs があり重大 drift なし |
| C | 構造は読めるが過剰/不足設計、または custom pattern のルールが未明示、または living docs が弱い/古い |
| F | `tree --gitignore` が不明瞭、規模に対して構造ミスマッチが大きい、または living documentation が存在しない/古い docs が孤立している |
