# Desktop の設計・検証・機能テスト

| ファイル | 内容 |
|---|---|
| `desktop.md` | 目的と制約 (v3)。本文は手段に依存しない |
| `handoff.md` | 引き継ぎ (2026-10-23)。検証の対象候補 D-V1〜D-V4 |
| `ledger.md` | 検証の台帳。各制約の「主張 / 結果 / 確認質問」と、Server への確認事項 |
| `checks/` | 文書そのものの機械検査 |
| `adr/` | 手段の決定 (段階2で作る) |

## 文書の検査

```bash
docs/platform/desktop/checks/no-provisional-must.sh                  # MUST に【仮】が無い
docs/platform/desktop/checks/ids-preserved.sh <旧版.md> <新版.md>    # 制約 ID を消していない
```

## Server との境界

Server は別のセッションで扱う。接点は `desktop.md` 7章の約束だけ。約束を変えたいときは `ledger.md` の「Server への確認事項」に書く。
