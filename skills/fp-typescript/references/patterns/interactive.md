# インタラクティブ型

状態+イベントループ。SPA, Desktop App が該当。
Elm Architecture (TEA) と F# Elmish がこのパターンの標準戦略。

## 核心: TEA (The Elm Architecture)

4つの要素で構成される：
- **Model** — アプリケーション状態（不変データ）
- **Msg** — ユーザー操作やイベントの記述
- **Update** — `(Model, Msg) → (Model, Cmd)` 状態遷移の純粋関数
- **View** — `Model → UI` 状態からUIへの純粋関数

副作用は Cmd（コマンド）としてデータで記述し、ランタイムが実行する。Update関数自体は純粋。

## 100%純粋にすべき部分

| 領域 | 理由 |
|---|---|
| Reducer / Update関数 | 設計上純粋であることが強制される |
| セレクタ / 派生状態 | メモ化との相性が良い |
| フォームバリデーション | 入出力が明確 |
| データ変換（API→ViewModel） | 副作用ゼロ |
| コンポーネントprops導出 | status → {label, disabled, variant} |
| URL / ルートパース | 文字列→構造体の変換 |

## IO層（純粋にしない）

Hook（Reactランタイムとの接点）、イベントハンドラ（DOM操作が本質）、API通信。

## TypeScriptでの段階的適用

TEAを「全か無か」ではなく段階的に適用する：
1. View を純粋にする（UI = f(props)）
2. 状態遷移を純粋にする（useReducer）
3. 純粋ロジックをHookの外に抽出する（フレームワーク非依存でテスト可能に）
4. 副作用をデータ化する（Cmdパターン、必要な場合のみ）

## TEAが困難になるケース

- 大量のフォームフィールド（各フィールドにMsgが冗長）
- UIの一時的状態（ドロップダウン開閉等、Modelに入れると肥大化）
- 高頻度イベント（マウス移動等）

これらの場合は「hooks + 純粋ロジック抽出」の方が実用的。

## アンチパターン

- UIコンポーネントの過度な汎用化（抽象化は関数レベルで活きる）
- イベントハンドラを無理に純粋にする（ハンドラは不純でOK、呼び出すロジックを純粋にする）
- Monadic IOの持ち込み（過剰。Effect-TSを使うならサービス/API層に限定）

## 参考

- Elm Architecture Guide: https://guide.elm-lang.org/architecture/
- F# Elmish: https://elmish.github.io/elmish/
- The Elmish Book: https://zaid-ajaj.github.io/the-elmish-book/
- Redux Prior Art (Elmの影響): https://redux.js.org/understanding/history-and-design/prior-art#elm

状態管理ライブラリ（Zustand, Jotai, Redux Toolkit, XState）のAPIは Context7 MCP で最新を取得すること。
