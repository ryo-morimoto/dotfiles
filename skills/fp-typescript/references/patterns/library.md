# ライブラリ型

IOなし、純粋計算。Library, SDK, Package が該当。
F#コミュニティの型駆動設計 (Type-Driven Design) がこのパターンの標準戦略。

## 核心: ライブラリは純粋なコアだけを提供し、IOは呼び出し側に委ねる

ライブラリ自体が副作用を実行しない。「何を計算するか」を提供し、「いつ・どこで実行するか」はユーザーコードが決める。

## 設計原則

| 原則 | 意味 |
|---|---|
| Make Illegal States Unrepresentable | 不正な値を型レベルで構築不可能にする |
| Smart Constructor | 生の値からの直接構築を禁止し、パーサー経由でのみ型付きデータを生成する |
| Total Function | 全入力に値を返す。例外を投げない |
| 参照透過性 | 同じ入力→常に同じ出力。関数のシグネチャが嘘をつかない |
| Pit of Success | APIの「一番簡単な使い方」が正しい使い方になる設計 |

## IO を含む SDK の場合

API Client / SDK のようにIOを含む場合は、純粋なコアと IOラッパーを分離する：

- 純粋コア: リクエスト構築、レスポンスパース、エラー分類
- IOラッパー: 実際の fetch 実行（薄い層）

理想的には IO の「記述」だけを返し、実行は呼び出し側に委ねる。

## テスト

純粋コードのテストは自明 — モック不要、セットアップ不要、非決定性なし。
Property-Based Testing（fast-check）との相性が良い。

よく使うプロパティ: Round-trip (`decode(encode(x)) === x`)、Idempotency (`f(f(x)) === f(x)`)、Invariant。

## アンチパターン

- ライブラリ内部で副作用を隠す（関数シグネチャが嘘をつく）
- 生のプリミティブ型をAPIに露出させる（string, number を直接受け取る）
- 例外で制御フローを行う（Result型を返す）

## 参考

- Scott Wlaschin "Designing with Types": https://fsharpforfunandprofit.com/series/designing-with-types/
- Scott Wlaschin "Domain Modeling Made Functional": https://fsharpforfunandprofit.com/books/
- Mark Seemann "Functional Design Is Intrinsically Testable": https://blog.ploeh.dk/2015/05/07/functional-design-is-intrinsically-testable/
- fast-check (Property-Based Testing): https://github.com/dubzzz/fast-check
