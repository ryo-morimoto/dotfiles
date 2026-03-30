# FP推奨ディレクトリ構造

既存の構造がない場合の推奨。プロジェクトの規模・チームの慣習があればそちらを優先すること。

## 推奨構造

```
src/
├── cmd/       エントリポイント。IOの実行のみ
├── prelude/   言語に足りない語彙（Result, Option, Brand, match）
├── lib/       ドメインロジック（純粋関数のみ）。ドメインごとに垂直分割
└── io/        副作用のラッパー（fs, fetch, process等）
```

## 推奨の層依存ルール

```
cmd/     → lib/, io/, prelude/
lib/     → prelude/ のみ（io/ 禁止）
io/      → prelude/ のみ（lib/ 禁止）
prelude/ → 何も import しない
```

## 推奨のモジュール分割

ドメインごとに型・ロジック・テストを同居させる（垂直型）。

```
src/lib/
├── user/
│   ├── user.ts        型定義 + 純粋関数
│   └── user_test.ts   テスト
└── order/
    ├── order.ts
    └── order_test.ts
```

## 基盤ディレクトリの配置（AskUserQuestion対象）

ドメインが依存する基盤コード（prelude, shared, common等）の配置はプロジェクトごとに異なる。AskUserQuestionで確認する：

> 基盤コード（Result型, Brand型等）をどこに置きますか？
>
> **選択肢:**
> - `src/prelude/` — ドメインと同階層（推奨構造のデフォルト）
> - `src/lib/shared/` — lib内に共有モジュールとして配置
> - `packages/core/` — モノレポの共有パッケージとして分離
> - プロジェクトの既存パターンに合わせる

参考:
- Haskell: `app/` と `src/` の分離、垂直型モジュール
- MoonBit: `src/` をルート、テストはソースの隣
