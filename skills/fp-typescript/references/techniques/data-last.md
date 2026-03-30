# カリー化とdata-last

合成可能な引数設計。TSでは型推論の制約からdata-firstをデフォルトにする。

## いつ/いつでない

- 「設定→操作」パターン（`createLogger(config)` → `Logger`） → カリー化が自然
- パイプライン内で使う関数 → data-last が合成しやすい
- それ以外 → 通常の引数で十分

## 参考

- F# Partial Application: https://fsharpforfunandprofit.com/posts/partial-application/
- Haskell Currying: https://wiki.haskell.org/Currying
- Remeda data-first+data-last: https://remedajs.com/docs#pipe
