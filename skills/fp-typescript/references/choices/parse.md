# パースライブラリ候補

AskUserQuestionでパースライブラリを選ぶ際の候補。APIは Context7 MCP で最新を取得すること。

## 安定性情報（変わりにくい）

| ライブラリ | URL | v1.0+ | 破壊的変更の頻度 |
|---|---|---|---|
| Zod | https://zod.dev | v3安定。v4(Mini)で一部API変更、移行パスあり | 低（v3内は安定） |
| Valibot | https://valibot.dev | v1.0リリース済（2024末）。semver準拠 | 低（v1以降安定） |
| ArkType | https://arktype.io | v2.x（2025）。比較的新しい | 未確定（新しい） |
| @effect/schema | https://effect.website/docs/schema | Effect 3.xに連動 | Effectと同期（活発） |
| Superstruct | https://github.com/ianstormtaylor/superstruct | v1.0+（2023） | 低活発 |

## 動的情報（スキル使用時にContext7 MCPで取得）

最終更新、週間DL数、バンドルサイズは変動するためスキル使用時に確認すること。

## 選定基準の推奨

- **エコシステム統合が最重要** → Zod（tRPC, React Hook Form等と統合）
- **バンドルサイズが重要**（Edge, クライアント）→ Valibot（1-2KB、tree-shake最適化）
- **パフォーマンスが重要** → ArkType（ベンチマーク最速クラス）
- **Effectエコシステム採用済み** → @effect/schema
- **pipe スタイルと親和性** → Valibot（`pipe(string(), email())` 形式）
