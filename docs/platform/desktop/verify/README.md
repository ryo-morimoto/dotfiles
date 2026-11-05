# 段階3: 検証の設計

対象は handoff.md 3章の D-V1〜D-V4。形式化に値するかどうかは、mizchi playbook (https://gist.github.com/mizchi/db7817e6fc077d567c41cd9d41bb1c53) の §1 (道具の選び方) と §7 (やめ時) で判断した。§7 の基準は次のとおり。

- **向く:** 全入力・全順序で成り立つべき性質、境界やエッジが多いもの、クロス境界の契約、「設定ミスが事故になる」もの、信頼境界。
- **向かない:** 確率的な性質、制御理論的な性質、テストで総当たり済みのものの再検証、確認のためだけの命題の量産。
- **やめ時:** 主要な不変条件と危険な穴を押さえたら、新しく形式化するより、溜まった反例と確認質問を片付ける。

PERF-\* は計測で扱う (handoff.md 3章)。

## 判断

| # | 対象 | 守る制約 | 判断 | 理由 | 道具 |
|---|---|---|---|---|---|
| D-V1 | 更新と巻き戻し | REL-1, REL-2, MNT-1 | **値する** | 順序の問題である (壊れたまま更新を重ねる、cleanup、ESP の上限、電源断、設定の一方通行の移行)。Q1 で鮮度を上に置いたので、巻き戻しに頼る回数が増える。from-chart の時点で設計の穴が1つ出た (下記) | statechart (from-chart) → TLA+ (TLC) |
| D-V2 | niri 設定の読み込み順 | INT-1 | **値する** | 有限で決定的なので、全列挙が最も安い (§1)。節ごとに合成の規則が違い、「後に読んだものが勝つ」が節によっては成り立たない (下記)。設定ミスが黙って効かなくなる型である | 全列挙 (Python の標準ライブラリだけ) |
| D-V3 | 推論 API の公開範囲 | SEC-1 | **値する** | 信頼境界で、優先順位1位。fail-open の経路がありうる。たとえば podman の port publish は自前の nftables 規則で DNAT するので、ホストの input チェーンの規則を素通りするおそれがある [推論。モデルと実機で確かめる]。入力 (送り元の種類 × インターフェース × Tailscale のタグ) の同値類は有限 | 全列挙。実機テストでも確かめる (段階4) |
| D-V4 | ディスクの指定 | SAF-1 | **値する** | 取り返しがつかない (優先順位1位)。性質は構造的 (消去コマンドは1つの関数からだけ呼ばれ、引数は宣言から来る) で、静的に検査できる。費用が小さい | 静的検査 (消去の入口を Python で書き、`ast` で検査する) |

4つとも値すると判断した。そのうえで、それぞれ1つの名前付き invariant に絞る。確認のためだけの命題は足さない。

## D-V1: 挙動の合意 (from-chart)

statechart の from-chart で、利用者から見た挙動を図にした。TLA+ の文字列は ASCII に限られるので、図のラベルは英語にした。日本語の対訳は下の表にある。

- 今の設計 (ADR-0002 のまま): `d-v1/current/` (`chart.png`、`bug-1.png`、`stories.md`)
- 提案: `d-v1/proposed/`

| 図の状態 | 意味 |
|---|---|
| Desktop works | 作業面が動いている |
| Broken by update, good entry kept | 更新で壊れた。ブートメニューに、動いた状態のエントリが残っている |
| Updated again while broken, good entry kept | 壊れたまま更新を重ねた。動いた状態のエントリはまだ残っている |
| Broken, no good entry in boot menu | 壊れていて、ブートメニューに動いた状態のエントリが無い |
| Booted from snapshot | スナップショットから起動した |
| Old version, settings in new format | 旧版に戻ったが、設定は新しい形式のまま |

**規則 (invariant):** `NoWayBack` — 作業面が壊れたとき、ブートメニューには必ず動いた状態のエントリが残っている。

**今の設計で TLC が出した反例** (`d-v1/current/stories.md`):

0. 作業面が動いている。
1. 更新で作業面が壊れる。
2. 壊れたまま、さらに更新する。snap-pac は壊れた状態のスナップショットを新しく取る。
3. snapper の cleanup (件数の上限) が古いスナップショットを消す。ESP が上限に達して limine-snapper-sync が古いエントリを消す、という経路でも同じ状態になる。→ 動いた状態のエントリが無くなる。

**提案** (ADR-0002 への追加案):

- **動いた印を付ける。** 作業面が起動してログインできたら、そのときのスナップショットに「動いた」印を付ける (snapper の userdata の `important=yes`)。
- **印の付いたものは cleanup で消さない。** 最新の2つを残す (`NUMBER_LIMIT_IMPORTANT`)。
- **ESP の上限より先に件数の上限が効くようにする。** スナップショットのエントリの件数の上限を、ESP に収まる数より小さくしておく。

提案の図では、`NoWayBack` は成り立つ。

**モデルが扱わないこと**

- 時間 (15分) は扱わない。時間は機能テストで測る。
- 「動いた」の判定に引っかからない壊れ方は扱わない。たとえば、作業面は起動するが日本語入力が壊れている場合である。この場合も印が付く。

### TLA+ のモデルで見つかったこと (2026-10-24)

合意した図 (`d-v1/proposed`) を受けて、各部品の実際の振る舞いを入れたモデルを書いた (`d-v1/model/Rollback.tla`)。モデルに入れた部品と、根拠にしたソースは次のとおり。

| 部品 | 振る舞い | 出典 |
|---|---|---|
| snap-pac | トランザクションごとに pre と post を取る | snap-pac 3.0.1 |
| snapper の number cleanup | 新しい順に `NUMBER_LIMIT` 件と、important の `NUMBER_LIMIT_IMPORTANT` 件を残す | snapper `client/cleanup.cc` |
| limine-snapper-sync | `MAX_SNAPSHOT_ENTRIES` を超えた分は、古いエントリから消す (important は見ない)。ESP が上限なら新しいエントリを足さない | `SnapshotManager.java`、README |
| limine-snapper-restore | 戻すたびに、壊れた側を backup のエントリとして足す | README |

**合意した図のままでは、規則 `NoWayBack` が破れる** (`agreed.cfg`)。図では「動いた印を付け、cleanup は印を消さない」としたが、起動エントリを消すのは snapper ではなく limine-snapper-sync で、こちらは印を見ない。反例は3手である。

1. 更新で壊れる。
2. 壊れたまま、もう一度更新する。新しいスナップショットのエントリが増える。
3. `MAX_SNAPSHOT_ENTRIES` を超えた分を limine-snapper-sync が古い順に消す。動いた印の付いたエントリも消える。

**提案** (`proposed.cfg`。ここでは2つの規則が両方成り立つ):

- **(a) 動いた印:** ログインできたら、`important=yes` と `desktop_good=yes` を付けたスナップショットを作る。
- **(b) pacman のフック:** 更新すると、最新の `desktop_good` のエントリが件数の上限で押し出される場合は、更新を止める (fail-closed)。
- **(c) 復元のラッパー:** 復元は `desktop_good` の付いたスナップショットからだけ行う。
- **(d) 件数の上限:** `MAX_SNAPSHOT_ENTRIES` は数値で決め、ESP に収まるエントリの数より小さくする。
- **(e) snap-pac の `important_packages` は無効のままにする。** これは既定値である。

規則は2つある。

- `NoWayBack` (合意した規則): 作業面が壊れたとき、ブートメニューには必ず動いた状態のエントリが残っている。
- `UpdatesStayPossible` (追加): (b) が fail-closed なので、印が無いと更新が一切できなくなり、`NoWayBack` は空虚に成り立ってしまう。これを検出するための規則である。作業面が動いていてログインした直後は、更新できなければならない。

**壊した版** (どれも期待どおりに失敗する):

| 設定 | 壊したところ | 破れる規則 |
|---|---|---|
| `agreed.cfg` | (b) のフックが無い (合意した図のまま) | NoWayBack |
| `broken-no-mark.cfg` | (a) の印を付けない | UpdatesStayPossible |
| `broken-pick-any.cfg` | (c) が無く、印の無いものからも復元する。復元のたびに backup のエントリが増え、印のあるエントリを押し出す | NoWayBack |
| `broken-entries-ge-esp.cfg` | (d) が無く、件数の上限が ESP の容量と同じ | UpdatesStayPossible |
| `broken-important-on-update.cfg` | (e) が無く、snap-pac が important を付ける | NoWayBack |

**範囲:** スナップショットは12個まで。`NUMBER_LIMIT=4`、`NUMBER_LIMIT_IMPORTANT=2`、`MAX_SNAPSHOT_ENTRIES=7`、ESP の容量はエントリ8件分、1回の decman で pacman のトランザクションは2回。成り立ったのはこの範囲での話で、実際の数値では段階4で計測する。

**MNT-2 への影響:** (b) のために、ログインしてから次に再起動・ログインするまでにできる更新の回数に上限ができる。回数は ⌈`MAX_SNAPSHOT_ENTRIES` ÷ (2 × トランザクション数)⌉ − 1 回である。例: `MAX_SNAPSHOT_ENTRIES=30` で、1回の decman が3トランザクションなら4回。decman の1回を1組の pre / post にまとめれば14回になる [推論。snap-pac をその間だけ止める方法は段階5で確かめる]。

**1コマンドで再実行:** `docs/platform/desktop/verify/run.sh` (TLA+ tools v1.7.4 を sha256 で固定して取得し、各 cfg の `expect:` と照合する)。

## D-V2: niri 設定の層 (全列挙)

**性質:** `DmsUiWriteAlwaysWins` — `dms/*.kdl` が定めた項目は、ほかの層が同じ項目を定めていても、実際に効く値が `dms/*.kdl` のものになる。

**モデル:** `d-v2/niri_layers.py`。niri の合成規則を、項目の種類ごとの「どの層が効くか」の表にした。根拠は niri の commit e19df12 (2026-10-21) のソースである。

| 項目の種類 | 効くもの | 出典 |
|---|---|---|
| 多くの節 (layout、cursor、blur、recent-windows など) の各項目 | 後の層 | `niri-config/src/lib.rs:198-209, 250, 286` |
| 合成しない小節 (struts など) | 後の層 (丸ごと置き換える) | docs `Configuration:-Include.md` |
| binds のキー | 後の層 | `lib.rs:223-235` |
| フラグ | 後の層 | `lib.rs:241` |
| window-rule の各項目 | 後の層 (順に適用し、後が上書きする) | `lib.rs:218`、`src/window/mod.rs:203` |
| **同じ画面の output 節** | **前の層** (最初に一致したもの) | `lib.rs:212-215`、`output.rs:150` |

読み込み順と、同じ項目をどの層が定めるかの組み合わせを、すべて調べた。

**結果:** 規則を2つ置くと、性質が成り立つ。

- R1: `output` 節は `dms/outputs.kdl` にだけ書く。
- R2: `dms/*.kdl` の include を `config.kdl` の最後に置く。

壊した版は期待どおりに失敗する。

- R1 を外した版: 前の層の output が効き、DMS の画面設定が無視される。
- R2 を外した版: dms の後に読んだ層が上書きする。
- `lint` はこの2つの規則を実際の KDL ファイルについて検査する。fixture で確かめた (`fixtures/good`、`broken-output-in-local`、`broken-dms-not-last`)。段階5では、作った設定ファイルを入力にする。

**範囲:**
- 合成規則の表は、ソースを読んで書いた。実物の niri で効いた値を確かめるのは機能テストで行う。具体的には `niri validate` と、`niri msg outputs` で画面のモードを読むことである。
- KDL の読み取りは最上位のノードだけである。対応しているのは、文字列、コメント、`/-`、入れ子。

## D-V3: 推論 API の公開範囲 (全列挙)

**性質:** `InferenceOnlyFromAllowedPeers` — 推論 API のポートへの接続が受け付けられるのは、自分の端末・Server のノード・Desktop 自身からだけ。許可した相手に届かない設定 (空虚に成り立つもの) も失敗にする。

**モデル:** `d-v3/inference_exposure.py`。送り元の同値類 (自分の端末、Server、そのほかの tailnet の端末、LAN、インターネット、Desktop 自身) と、届くインターフェース、宛先アドレスを、すべて調べる。

**結果:** 設計 (`designs/design.json`) では成り立つ。設計の中身は次のとおり。
- `Network=host` で動かす。
- Tailscale のアドレスで待ち受ける。
- nftables は `iifname` で `tailscale0` と `lo` だけを受け入れる。
- ACL は自分の端末と Server だけを許す。

壊した版は期待どおりに失敗する。

| 壊した版 | 届いてしまう相手 |
|---|---|
| ACL が全許可 | ほかの tailnet の端末 |
| podman の `PublishPort=8080` | LAN とインターネット。netavark の DNAT が input チェーンを素通りする |
| nftables を宛先アドレスで判定 | LAN から Tailscale のアドレス宛てに送ると届く (weak host model) |
| 0.0.0.0 で待ち受け、nftables も無し | LAN とインターネット |
| nftables が tailscale0 も止める | 誰にも届かない (失敗にする) |

参考: 0.0.0.0 で待ち受けても、nftables があれば成り立つ。層が重なっていることの確認である。

この結果を ADR-0003 の決定3に反映した (`Network=host`、`iifname` で判定)。ACL は Server 側の設定なので前提として扱い、`server-requests/0001-inference-acl.md` で依頼した。実機での確かめは段階4の `drive/inference-reachability` で行う。

## D-V4: ディスクの消去 (静的検査)

**性質:** `WipeTargetsOnlyDeclaredIds` — `install/` の下で、消去・初期化のコマンドを呼ぶのは `wipe.py` の `wipe_declared` の中だけ。そこに渡すデバイスは `resolve_declared(...)` の戻り値だけ。

**検査:** `d-v4/wipe_static_check.py`。Python の `ast` で、subprocess の呼び出しを全部調べる。shell スクリプトでは消去コマンドを一切禁じる。コマンド名が静的に分からない呼び出しは、消去とみなす (fail-closed)。

| 規則 | 内容 |
|---|---|
| W1 | 消去コマンドは `wipe_declared` の中だけで呼ぶ |
| W2 | `/dev/...` のリテラルを渡さない。`resolve_declared` の戻り値以外を渡さない |
| W3 | `shell=True` と `os.system` を使わない |
| W4 | 解決する前に消さない |

**結果:** `fixtures/good` では成り立つ。壊した版6つ (外で mkfs する、リテラルのデバイス、解決していない変数、`shell=True`、shell から wipefs、解決の前に blkdiscard) は、どれも失敗する。`fixtures/good/install/` は段階5の `install/` の雛形になる。

**範囲:** `resolve_declared` の中身 (by-id の解決、シリアル番号と容量の照合、マウントの確認、入力での確認) は実行時の振る舞いなので、ここでは検査しない。機能テスト `drive/install-from-zero` で、VM の loop デバイスを使って確かめる (代用)。

## 道具の版

| 道具 | 版 | 確認 |
|---|---|---|
| TLA+ tools (TLC) | v1.7.4 (TLC 2.19)、`tla2tools.jar` の sha256 `936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88` | https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4 |
| statechart スクリプト | cursor/plugins の commit `8b3326d99fd4b993cb33a24dad8af03175c642c5` (2026-10-22) の `pstack/skills/statechart/scripts` | — |
| Node.js | 22 | — |
| Java | 21 (OpenJDK) | — |
| Mermaid の PNG 出力 | `npx @mermaid-js/mermaid-cli` (statechart が呼ぶ) | 版は D-V1 の確定時に固定する |

1コマンドでの再実行は `verify/run.sh` (D-V1〜D-V4、壊した版を含めて26件、約10秒)。D-V2〜D-V4 は Python 3.11 以上の標準ライブラリだけで動く。
