---
name: verify-desktop
description: Desktop (Arch + niri + DMS + 推論 API) を利用者と同じ経路で動かし、作業面・推論 API の公開範囲・巻き戻し・宣言の適用・ゼロからの再現を確かめて証拠を残す。docs/platform/desktop/ の機能テスト (段階4) を実機か代わりの環境で回すとき、構成を変えた後に動くことを示すときに使う。
---

# Desktop の機能テスト

Desktop は1台の物理マシンである。テストの道具は `docs/platform/desktop/functional/dv` 1本で、Launch / Doctor / Drive / Evidence / Cleanup を順に行う。機能ごとの手順は [`features/`](features/README.md) にある。

## 実機か代わりの環境か

| `DV_TARGET` | どこで | 動かせる機能 |
|---|---|---|
| `real` (既定) | 実機の Desktop。niri にログインした端末から実行する | すべて |
| `standin` | Linux の network namespace (root が要る) | `inference` の公開範囲だけ。nftables の規則は本番と同じ生成器で作り、tailscale0 は veth で模す |

代わりの環境で通ったものは「代用で PASS」であって、実機での PASS ではない。違いは各 feature の `Gotchas` にある。

## Launch

```bash
# 実機: 起動とログインの完了を待つ。推論サービスが止まっていれば起動する (cleanup で止める)
docs/platform/desktop/functional/dv launch

# 代わりの環境: namespace を3つ作り、nftables の規則と推論の代わりのサーバーを入れる
sudo DV_TARGET=standin DV_RUN_ID=<任意の ID> docs/platform/desktop/functional/dv launch
```

- 準備ができると `ready: ...` と出る。
- `DV_RUN_ID` は launch / drive / cleanup で同じ値を使う。省くと日時になり、別の実行とみなされる。
- 二重に起動しない: `DV_RUN_ID` ごとに namespace の名前を分けるので、代わりの環境は並べて動かせる。実機は1台なので、同時に2つ動かさない。

## Doctor

```bash
docs/platform/desktop/functional/dv doctor
```

読むだけの点検で、「この環境を検証してよいか」に答える。実機では次を確かめる。何か変だと感じたら、まずこれを回す。

- OS が Arch Linux である。
- NVIDIA ドライバ、niri のセッション、Tailscale が動いている。
- snapper の root と home の設定がある。
- 推論サービスが動いている。
- 証拠の置き場所に書ける。

## Drive

```bash
docs/platform/desktop/functional/dv drive <feature>
```

| feature | 守る制約 | 手順 |
|---|---|---|
| `workspace` | FUN-1, PERF-4, INT-1 | [features/workspace.md](features/workspace.md) |
| `inference` | FUN-3, COMP-2, SEC-1, PERF-1, PERF-5 | [features/inference.md](features/inference.md) |
| `rollback` | REL-1, REL-2 | [features/rollback.md](features/rollback.md) |
| `declare-apply` | MNT-2, MNT-3, INT-3 | [features/declare-apply.md](features/declare-apply.md) |
| `install-from-zero` | FLX-3, SAF-1 | [features/install-from-zero.md](features/install-from-zero.md) |

各 check は `pass` / `fail` / `skip` を出す。

- **exit code:** fail があれば 1。fail が無く skip があれば 3。全部 pass なら 0。
- **skip は pass ではない。** 前提が無くて確かめていない、という意味である。台帳には skip のまま書き、理由を添える。
- **人の操作が要る手順は skip にする。** 対象はブートメニューでの選択、DMS の設定画面の操作、宣言の編集で、手順と記録のしかたは feature のファイルにある。

## Evidence

```bash
docs/platform/desktop/functional/dv evidence   # 今回の証拠の置き場所を出す
```

- 証拠は `${DV_EVIDENCE_ROOT:-~/.local/state/desktop-verify/evidence}/<DV_RUN_ID>/<feature>/` に残る。
- check ごとに `<id>.cmd`、`<id>.stdout`、`<id>.stderr`、`<id>.exit` がある。
- 一覧は `results.tsv` (id、判定、説明)、実行の情報は `meta.txt` (target、host、dotfiles の commit、時刻、pass / fail / skip の数) にある。

**証拠の基準:**
- 利用者の経路で動かす。具体的には curl で API を叩く、niri msg で画面の状態を読む、ssh で別の端末から叩く。内部の値を書き換えて確かめたことにしない。
- 「届かない」の確認では、TCP がつながったかどうかで判定する (`CONNECTS`)。HTTP の 401 は「届いた」に数える。
- 台帳 (`docs/platform/desktop/ledger.md`) に結果を書くときは、`results.tsv` の行と証拠のパスを添える。

## Cleanup

```bash
docs/platform/desktop/functional/dv cleanup
sudo DV_TARGET=standin DV_RUN_ID=<同じ ID> docs/platform/desktop/functional/dv cleanup
```

- 片付けるのは、その実行が作ったものだけである。`~/.local/state/desktop-verify/runs/<DV_RUN_ID>/started.txt` に記録した namespace、pid、ユニットを止める。
- プロセス名で kill しない。
- 証拠は消さない。

## 補助スクリプト

| スクリプト | 使い方 |
|---|---|
| `functional/gen_nft.py <design.json>` | 推論 API の nftables の規則を宣言から作る。本番も代わりの環境も、これを使う |
| `functional/vram.sh resident-mib \| per-process \| total-mib` | VRAM の計測 (PERF-1 / PERF-5) |
| `functional/undeclared.sh` | 宣言されていない状態の一覧 (INT-3)。既知のものは `functional/known-undeclared.txt` に理由と一緒に書く |
| `functional/standin/broken-*.nft` | 代わりの環境で検査が効いていることを確かめるための、壊した規則。`DV_STANDIN_NFT=<file>` で使う |

## 形式検証との関係

形式検証 (`desktop-formal-verification` skill) は、設計と宣言について、すべての場合を調べる。この skill は、実物がその設計どおりに動くことを確かめる。両方の結果を、台帳の同じ制約の行に書く。
