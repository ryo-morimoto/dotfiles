---
name: fp-typescript
description: >
  TypeScriptアプリケーションを関数型プログラミング（FP）スタイルで設計・実装・リファクタリングするためのスキル。
  「TypeScriptを関数型にしたい」「手続き型コードをFPにリファクタしたい」「副作用を分離したい」
  「Result型やOption型を使いたい」「FPのディレクトリ構造を知りたい」「pure functionとIOを分けたい」
  といった場面で必ず使用すること。CLI・フロントエンド・サーバー問わず適用可能。
  Also trigger when: creating a new TypeScript project with FP architecture, asking about
  immutable data patterns, wanting to eliminate side effects, discussing pure functions vs IO,
  mentioning "prelude" or "algebraic data types" in TypeScript context, refactoring
  imperative/OOP TypeScript code toward a functional style, or separating business logic
  from side effects in React/Next.js/Hono/Express applications.
---

# FP TypeScript スキル

## FPの核心（普遍原則）

1. **Functional Core, Imperative Shell** — 判定（decision）は純粋関数、実行（execution）は薄いシェル
2. **Parse, Don't Validate** — 境界で `unknown → 型付きデータ` に変換し、内部は再検証しない
3. **不正な状態を型で排除する** — Sum型（discriminated union）で状態を表現し、booleanフラグを避ける
4. **網羅性をコンパイラに保証させる** — 全バリアントを処理したことを型で証明する
5. **Total Function** — 関数は全入力に値を返す。throwせずResult型で失敗を表現する
6. **immutable** — データを変更せず新しいデータを返す

## アプリケーションパターン別ガイド

すべてを純粋にするのは不可能だし目指さない。純粋にできる部分を100%純粋に保ち、IOは最小限の薄い層に閉じ込める。

パターンごとにFP戦略が根本的に異なる。副作用の流れ方で3つに分類される：

| パターン | 副作用の流れ | 核心戦略 | 該当するもの | reference |
|---|---|---|---|---|
| **パイプライン型** | 入力→変換→出力 | Impureim Sandwich (IO→Pure→IO) | HTTP Server, CLI, Script, Edge Function, Background Job | `references/pattern-pipeline.md` |
| **インタラクティブ型** | 状態+イベントループ | TEA (Model→Msg→Update→View) | SPA, Desktop App | `references/pattern-interactive.md` |
| **ライブラリ型** | IOなし（呼び出し側に委ねる） | 型駆動設計、参照透過性 | Library, SDK, Package | `references/pattern-library.md` |

## ワークフロー

### 前提確認（コードを書く前に必ず実行）

1. **tsconfig.json を確認する** — `strict: true`, `noImplicitReturns: true` がないとFP原則が型レベルで機能しない。不足があればユーザーに指摘する
2. **package.json を読む** — 依存傾向と既存ライブラリを把握する（次の判断に使う）

詳細: `references/ts-pitfalls.md`

### 自前実装 vs ライブラリの判断（全choicesの前提）

ライブラリ選定のAskUserQuestionを投げる前に、プロジェクトの依存傾向を自動判断する：

1. **package.json（または類似のパッケージ管理ファイル）を読む**
2. 以下のシグナルから傾向を推定する：
   - dependencies の数がプロジェクトのLOCに対して少ない → **依存を最小限に保つ方針**（自前実装を推奨）
   - dependencies が多い → **ライブラリを積極的に使う方針**
   - 小さなライブラリ（~数KB）ばかりでバンドルサイズを気にしている → **軽量ライブラリ or 自前実装を推奨**
   - 既にFP系ライブラリ（Effect, fp-ts, neverthrow等）がある → **そのライブラリに合わせる**
   - 既にZod/Valibot等がある → **パースはそれを使う（追加選定不要）**
3. 推定した傾向をAskUserQuestionに含める：

> package.jsonを見ると依存が少なめで、自前実装を好むプロジェクトに見えます。
> 自前実装とライブラリ導入、どちらが好みですか？

既存の依存から判断できる場合はAskUserQuestionを省略してよい（例: 既にZodがあるならパースはZod）。

### choices（AskUserQuestion対象）

以下の選択はプロジェクト/ユーザーに依存する。必要になった時点で、上記の依存傾向判断を踏まえてAskUserQuestionで確認する。ユーザーの回答は実装時に必ず反映すること。

| 選択 | 必要性の判断シグナル | reference |
|---|---|---|
| **FPの型** | try/catchでエラー処理している、null/undefinedチェックが散在、switch文にdefaultがない | `choices/fp-types.md`, `choices/fp-types-template.md` |
| **パースライブラリ** | `JSON.parse`の戻り値をanyで使っている、外部入力(API, CLI, ファイル)を型なしで処理している | `choices/parse.md` |
| **パイプ合成** | 変換が4ステップ以上連鎖している、一時変数が3つ以上並んでいる、ネストした関数呼び出しが読みにくい | `choices/pipe.md` |
| **不変更新** | spreadが3段以上ネストしている、同じ深いパスへの更新が複数箇所にある | `choices/immutable-update.md` |
| **ディレクトリ構造** | 新規プロジェクト、または純粋関数とIOが同じファイル/ディレクトリに混在している | `choices/directory.md` |

### 既存コードのリファクタリング

以下の順で進める。プロジェクトの状況に応じて取捨選択する：

0. **副作用の地図** — IO箇所を全マーキング
1. **IO分離** — 純粋関数とIOを別ファイルに分け、テストがIOをimportせず済む状態にする
2. **pipeline化** — forループを map/filter/reduce に変える
3. **immutable化** — mutation を新オブジェクト返却に変える
4. **DI** — グローバル依存を引数に昇格
5. **分割合成** — ドメイン概念を正しく反映する関数境界にする。ドメインがわからないときは分割せずユーザーに確認する（`techniques/composition.md` 参照）
6. **Result化** — try/catch を Result<T, E> に変える
7. **構造分離** — 規模に応じてディレクトリで分離する

## references/ 構造

```
references/
├── patterns/              アプリケーションパターン別ガイド（MECE）
│   ├── pipeline.md        入力→変換→出力（Server, CLI, Script, Edge, BG Job）
│   ├── interactive.md     状態+イベントループ（SPA, Desktop）
│   └── library.md         純粋計算（Library, SDK, Package）
├── choices/               ユーザー/プロジェクトに依存する選択（AskUserQuestion対象）
│   ├── fp-types.md        Result/Option/Brand/match → 自前 or ライブラリ
│   ├── fp-types-template.md  自前実装を選んだ場合の推奨テンプレート
│   ├── parse.md           パースライブラリ選定
│   ├── pipe.md            パイプ合成選定
│   ├── immutable-update.md 深いネスト更新選定
│   └── directory.md       ディレクトリ構造・基盤配置
├── techniques/            FPメンタルモデル+テクニック
│   ├── composition.md     合成 — いつ合成し、いつ1つの関数にするか
│   ├── data-last.md       カリー化/data-last — 合成可能な引数設計
│   ├── expression-oriented.md  式指向 — すべてが値を返す
│   ├── description-execution.md  記述と実行の分離 — 副作用をデータとして扱う
│   ├── parse-dont-validate.md  境界パース + Schema as SSOT
│   ├── adt.md             Sum型/Product型、網羅性チェック
│   ├── di.md              関数引数DI
│   └── resource-management.md  using/Disposable、acquireRelease
└── ts-pitfalls.md             TSでFP原則が壊れるポイント（tsconfig/eslint/違反パターン）
```

## 判断基準

**外部ライブラリのAPIを使うとき** → `references/sources.md` のURLを確認し、Context7 MCPで最新ドキュメントを取得してからコードを書く。スキル内のコード例は情報が古い可能性がある。

**外部ライブラリを推奨するとき** → ライブラリ名だけでなく、Context7 MCPで最新APIを取得してからコード例を書くこと。直接コード例を書かずにURLで誘導するだけでもよい。
