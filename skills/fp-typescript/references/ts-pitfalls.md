# TSでFP原則が壊れるポイント

## 必須設定

不足があればユーザーに指摘する。

- tsconfig: `strict: true`, `noImplicitReturns: true`, `noUncheckedIndexedAccess: true`（推奨）
- eslint: `eslint-plugin-functional`（導入済みか確認し、なければ提案）

## よくある違反と対策

| 問題 | 対策 |
|---|---|
| switch網羅性の穴 | `default: absurd(x)` またはts-pattern/exhaustiveパッケージ |
| optional再検証（パース後のundefinedチェック） | `.transform()`でパース時に解決 |
| Partial更新の手動列挙 | mapped型で網羅性を強制 |
| 型推論がpipe+genericsで崩壊 | 4段以上は中間`const`で切り、切れ目に型注釈を入れる |
| エラーメッセージが深いネスト型で読めない | モジュール境界で型エイリアスを定義しネストを浅く保つ |
| Over-engineering（5行→50行） | モナド変換子やHKTハックは避ける。Result/ADT/immutableだけで十分 |
| HKTがない | コンテナを抽象化しない。Result, Optionを具体型のまま使う |
| ホットパスでGC圧力 | 境界でだけResult/Optionを使い、ホットパスはプリミティブで処理 |
| チームが読めない | 段階的に導入する：Result → ADT → 純粋/IO分離 の順 |

## コミュニティの合意

> "The best FP in TypeScript is the FP that doesn't look like FP."

TSでは「FP-lite」（純粋関数+immutability+Result型+ADT）が最も実用的。Haskell/Scalaのパターンをそのまま持ち込むと失敗する。

## 参考

- ts-pattern: https://github.com/gvergnaud/ts-pattern
- exhaustive: https://github.com/lukemorales/exhaustive
- eslint-plugin-functional: https://github.com/eslint-functional/eslint-plugin-functional
- TS HKT issue (#1213): https://github.com/microsoft/TypeScript/issues/1213
