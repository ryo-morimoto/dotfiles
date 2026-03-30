# 深いネスト不変更新の候補

3段以上のspreadネストで検討。AskUserQuestionで選ぶ際の候補。

## 安定性情報（変わりにくい）

| ライブラリ | URL | アプローチ | v1.0+ | 破壊的変更 | 依存種別 |
|---|---|---|---|---|---|
| optics-ts | https://github.com/akheron/optics-ts | FP Lens/Prism | v2.x（v2以降3年安定） | 低 | runtime, ゼロ依存 |
| immer | https://github.com/immerjs/immer | Proxy draft | v11.x（長期活発） | v9以降API安定 | runtime, ゼロ依存 |
| mutative | https://github.com/unadlib/mutative | Proxy draft（immer互換+高速） | v1.x（2023〜） | 低 | runtime, ゼロ依存 |
| 自前Lens | — | FP Lens（30行程度） | — | — | なし |
| structuredClone + mutation | (組込み) | ディープコピー | Web標準 | — | なし |

## 避けるべき

- **monocle-ts** — fp-ts必須、事実上メンテ終了
- **immutability-helper** — メンテ終了（2020年最終更新）

## 動的情報（スキル使用時にContext7 MCPで取得）

最終更新、週間DL数、バンドルサイズは変動するためスキル使用時に確認すること。

## 選定基準の推奨

- **型安全性を最重視** → optics-ts（パス全体を型追跡）
- **学習コスト最低・エコシステム最大** → immer（React公式推奨）
- **immer互換+高速が必要** → mutative
- **依存を増やしたくない** → 自前Lens or structuredClone
- **FP Optics（合成・再利用）が必要** → optics-ts or 自前Lens
- **単発の深い更新だけ** → immer/mutative（Optics不要）
