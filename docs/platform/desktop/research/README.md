# research/

段階2 (構成の提案) の一次情報。数値は取得した日の値で、その日に取り直す。

| ファイル | 内容 |
|---|---|
| `freshness.py` | MNT-1 (鮮度) の計測。上流のリリース日と、各候補で使える版・届いた日を一次情報から取る |
| `snapshots/freshness-<日付>.{json,md}` | 計測の結果。日付は UTC |

```bash
python3 -m venv .venv && .venv/bin/pip install brotli==1.1.0
.venv/bin/python -I docs/platform/desktop/research/freshness.py --out-dir docs/platform/desktop/research/snapshots
```
