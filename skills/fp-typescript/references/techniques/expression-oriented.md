# 式指向

「この変数の値はどこから来るか」を常に1箇所で答えられるようにする。副作用の記述には文を、値の計算には式を。

## いつ/いつでない

- 値の初期化、条件分岐 → `const` + 式
- 深いネストや副作用が主目的 → 文で書く

## 参考

- Scott Wlaschin "Expressions vs Statements": https://fsharpforfunandprofit.com/posts/expressions-vs-statements/
- Rust Book Control Flow: https://doc.rust-lang.org/book/ch03-05-control-flow.html
- Rich Hickey "Simple Made Easy": https://www.infoq.com/presentations/Simple-Made-Easy/
