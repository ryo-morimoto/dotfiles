# FPライブラリ候補一覧

AskUserQuestionで自前実装かライブラリか確認する際の候補。APIは Context7 MCP で最新を取得すること。

## Result / Either

| ライブラリ | URL | サイズ | 備考 |
|---|---|---|---|
| neverthrow | https://github.com/supermacro/neverthrow | ~2KB | 最も人気。ResultAsync対応 |
| ts-results-es | https://github.com/lune-climate/ts-results-es | ~2KB | ESM-first |
| true-myth | https://github.com/true-myth/true-myth | ~3KB | Result + Maybe |
| oxide.ts | https://github.com/traverse1984/oxide.ts | ~2KB | Rust風API |

## Option / Maybe

| ライブラリ | URL | 備考 |
|---|---|---|
| true-myth | https://github.com/true-myth/true-myth | Maybe<T> |
| purify-ts | https://github.com/gigobyte/purify | Maybe + Either + Codec (~5KB) |
| oxide.ts | https://github.com/traverse1984/oxide.ts | Rust風 Option<T> |

## パターンマッチ

| ライブラリ | URL | 備考 |
|---|---|---|
| ts-pattern | https://github.com/gvergnaud/ts-pattern | exhaustive対応。~2KB |
| exhaustive | https://github.com/lukemorales/exhaustive | 軽量 switch/match ヘルパー (~1KB) |

## Brand / Newtype

| ライブラリ | URL | 備考 |
|---|---|---|
| Zod `.brand()` | https://github.com/colinhacks/zod | バリデーションと統合 |
| Effect Brand | https://github.com/Effect-TS/effect | ランタイム検証付き |

## オールインワン

| ライブラリ | URL | サイズ | 備考 |
|---|---|---|---|
| Effect | https://github.com/Effect-TS/effect | ~50KB+ (tree-shake可) | Result/Option/Brand/Match/Layer/Scope全部入り |
| purify-ts | https://github.com/gigobyte/purify | ~5KB | Either/Maybe/Codec。中規模向け |
| fp-ts | https://github.com/gcanti/fp-ts | ~15KB | メンテナンスモード。Effectに移行推奨 |

## 選定基準の推奨

- **依存を増やしたくない / ユースケースが限定的** → 自前実装（`references/prelude.md`）
- **Resultだけ欲しい** → neverthrow
- **パターンマッチだけ欲しい** → ts-pattern
- **複数の概念が必要だが軽量に** → purify-ts / true-myth
- **大規模・長期プロジェクト** → Effect
