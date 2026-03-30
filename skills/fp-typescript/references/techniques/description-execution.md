# 記述と実行の分離

副作用を「実行する」のではなく「値として記述」し、実行タイミングは呼び出し側が決める。TSでは `() => Promise<A>` が最軽量な実現手段。

## いつ/いつでない

- 複数の副作用を組み合わせるワークフロー → 分離が有効
- 単発のAPI呼び出し、一回限りの処理 → overkill

## 参考

- Haskell IO inside: https://wiki.haskell.org/IO_inside
- Elm Effects: https://guide.elm-lang.org/effects/
- Effect-TS Why Effect: https://effect.website/docs/getting-started/why-effect
