# パイプライン型

入力→変換→出力。HTTP Server, CLI, Script, Edge Function, Background Job が該当。
F#コミュニティでは Railway Oriented Programming (ROP) と Impureim Sandwich がこのパターンの標準戦略。

## 核心: Impureim Sandwich

処理を IO→Pure→IO のサンドイッチにする。複数段（IO→Pure→IO→Pure→IO、"Dagwood Sandwich"）も実用的。

```
Parse（境界パース）→ Validate（純粋）→ Load（IO）→ Execute（純粋）→ Persist（IO）→ Format（純粋）
```

## 100%純粋にすべき部分

| 領域 | 理由 |
|---|---|
| 入力パース・バリデーション | 決定論的変換 |
| ビジネスルール判定 | テスト容易性の核心 |
| 認可ポリシー評価 | (user, resource) → permission |
| データ変換・計算 | 副作用ゼロ |
| エラー分類・マッピング | DomainError → OutputError |
| 出力フォーマット | Domain → DTO/文字列 |
| リトライ判定ロジック | (error, attempt) → { retry, delay } |

## IO層（純粋にしない）

DB、外部API、ファイルIO、stdout、ログ出力。これらは副作用として受け入れ、前後の純粋ロジックを分離する。

## Result型によるエラーチェーン（ROP）

パイプラインの各ステップが Result を返し、どこかで失敗すれば即座に Failure トラックへ。
Wlaschin自身が「ROPの過剰適用」を警告している — Result型は「失敗の種類がビジネス的に意味を持つ」場面だけに使う。

## アンチパターン

- DBクエリを純粋に見せかける
- 全関数にResult型を適用する（toUpperCase に Result は不要）
- 純粋関数に渡すために不要なデータを事前フェッチする
- ミドルウェアの過剰な関数合成

## 参考

- Scott Wlaschin "Railway Oriented Programming": https://fsharpforfunandprofit.com/rop/
- Scott Wlaschin "Against Railway-Oriented Programming"（過剰適用への警告）: https://fsharpforfunandprofit.com/posts/against-railway-oriented-programming/
- Mark Seemann "Impureim Sandwich": https://blog.ploeh.dk/2020/03/02/impureim-sandwich/
- Mark Seemann "Dagwood Sandwich": https://blog.ploeh.dk/2023/10/09/dagwood-sandwich/
- Mark Seemann "Dependency Rejection": https://blog.ploeh.dk/2017/02/02/dependency-rejection/

フレームワークのAPIは Context7 MCP で最新を取得すること。
