---
name: desktop-formal-verification
description: Desktop の巻き戻し・niri 設定の層・推論 API の公開範囲・ディスク消去の形式検証 (D-V1〜D-V4) を再実行し、変更が検証済みの性質を壊していないか確かめる。docs/platform/desktop/ の ADR、snapper / limine-snapper-sync / snap-pac の設定、niri の KDL、nftables / Quadlet、install/ を変えたときに使う。
---

# Desktop の形式検証 (D-V1〜D-V4)

Desktop の設計で、壊れると取り返しがつかないか、テストでは踏みにくい性質を4つ検証している。この skill の役目は3つある。変更がそれに触れるかを判断すること、検査を回すこと、失敗を読んで直すこと。

## まず実行する

```bash
docs/platform/desktop/verify/run.sh
```

- 全部が `ok` なら exit 0。約10秒で終わる。
- 要るのは java (11 以上)、python3 (3.11 以上)、curl、sha256sum。
- TLA+ tools v1.7.4 は `~/.cache/desktop-verify/` に取得し、sha256 `936a2620…0e88` で照合する。

各行は「期待 (expect)」と「結果 (got)」を並べて出す。壊した版 (`broken-*`) は**失敗するのが正しい**。失敗するはずの版が通ったら、検査が効いていないということなので、それ自体がバグである。

## 何を検証しているか (範囲の記録)

| 検査 | 性質 | 守る制約 | 対象 (変えたら再確認する) | モデル / 検査 |
|---|---|---|---|---|
| D-V1 | `NoWayBack`: 作業面が壊れたとき、ブートメニューに動いた状態のエントリが必ず残る。`UpdatesStayPossible`: ログイン直後は更新できる | REL-1, REL-2 | ADR-0002 の決定 2, 3, 9〜13。snapper の root 設定 (`NUMBER_LIMIT`、`NUMBER_LIMIT_IMPORTANT`)、`/etc/snap-pac.ini`、`/etc/default/limine` (`MAX_SNAPSHOT_ENTRIES`、`LIMIT_USAGE_PERCENT`)、動いた印のサービス、pacman の押し出し防止フック、復元のラッパー | `docs/platform/desktop/verify/d-v1/model/Rollback.tla` と `*.cfg` |
| D-V2 | `DmsUiWriteAlwaysWins`: `dms/*.kdl` が定めた項目は必ず効く | INT-1 | ADR-0004 の R1 / R2。niri の `config.kdl` と include 先 (段階5で `dot-config/chezmoi/dot_config/niri/` に置く) | `docs/platform/desktop/verify/d-v2/niri_layers.py` (`model` と `lint`) |
| D-V3 | `InferenceOnlyFromAllowedPeers`: 推論 API に届くのは、自分の端末・Server・Desktop 自身だけ | SEC-1 | ADR-0003 の決定 3。`verify/d-v3/designs/design.json` (nftables と Quadlet はここから作る)。Tailscale の ACL (`server-requests/0001-inference-acl.md` の前提) | `docs/platform/desktop/verify/d-v3/inference_exposure.py` |
| D-V4 | `WipeTargetsOnlyDeclaredIds`: 消去コマンドは `wipe_declared` の中だけで呼び、デバイスは `resolve_declared` の戻り値だけ | SAF-1 | ADR-0006。`install/` 以下 (段階5で作る。今は `verify/d-v4/fixtures/good/install/` が雛形) | `docs/platform/desktop/verify/d-v4/wipe_static_check.py` |

**同期した commit:** `60b552542a1e69bc36960c6ab4a311e8fae7e8fe` (2026-10-24)。この commit の時点で、モデルが上の対象を正しく描いていることを確かめた。

**モデルが依っている上流のソース** (上流が変わったら、モデルの表を見直す):
- snapper `a4fb1ef` の `client/cleanup.cc:530-560`
- limine-snapper-sync `b4c0da2` の `SnapshotManager.java:68-127`
- niri `e19df12` の `niri-config/src/lib.rs:160-300`、`output.rs:150`、`src/window/mod.rs:203`
- netavark `8f38dd8` の `src/firewall/nft.rs:197-283`

## 変更が触れるかの判断

1. `git diff <同期した commit>..HEAD --stat` を見て、上の「対象」の列のファイルを変えているか確かめる。
2. 上の「上流のソース」の部品の版を上げたら、その部品の振る舞いがモデルの表と合っているかを読み直す。対象は、snapper、limine-snapper-sync、niri、netavark / podman。
3. どれにも触れていなければ、`run.sh` を回して `ok` を確かめるだけでよい。

## 失敗の読み方

- **`proposed.cfg` / `design.json` / `fixtures/good` / `model` が失敗した** → 設計か設定が性質を破った。TLC やスクリプトが出す反例 (状態の列、届いてしまう経路、違反の行) を、ADR と設定の言葉で読み直す。例: 「壊れたまま更新を2回すると、動いたエントリが件数の上限で消える」。
  - 実物がその手順で本当に壊れるかを、まず確かめる。壊れるならバグなので、設定か設計を直す。
  - 実物ではありえない手順なら、モデルの誤りである。モデルのどの行が実物と違うかを、上流のソースか設定の行で示してから、モデルを直す。
- **`broken-*` が通った** → 検査が効いていない。壊した部分が性質に効かなくなる変更をしたはずなので、検査かモデルを直す。
- **`error`** → TLC の構文エラーか、スクリプトの例外。出力の先頭5行を見る。

**してはいけないこと:**
- 反例を消すために、性質を弱めたり、モデルの振る舞いを減らしたりしない。
- 反例を消すために `Bound` を下げない。
- 規則を変えたいときは、ADR を改訂してユーザーの合意を取ってからにする。

## 意図した変更のとき

1. 変更に合わせて、モデルの該当行を直す。D-V1 は action と定数、D-V2 は `KINDS` / `DMS_WRITES`、D-V3 は `SOURCES` と `reachable`、D-V4 は `DESTRUCTIVE` と規則 W1〜W4 である。コメントには根拠 (上流のソースの行か、設定ファイルの行) を書く。
2. 直した性質が壊れる版を、`broken-*` として1つ足す。
3. `run.sh` を回し、全部 `ok` になることを確かめる。
4. 上の「同期した commit」を新しい commit に進める。進めてよいのは、モデルがその commit の対象を正しく描いていると確かめたときだけ。
5. `docs/platform/desktop/ledger.md` の該当する制約の行と、`verify/README.md` を直す。

## 範囲外

- 時間 (15分で戻れるか、1時間で再現できるか) と性能は、機能テストで測る。
- `resolve_declared` の実行時の振る舞いは、機能テストで確かめる。
- niri の実物で効いた値、nftables の実物の規則、Tailscale ACL の実物は、機能テスト `drive/*` で確かめる。
- D-V1 の範囲は、スナップショット12個までの小さい数値である。
