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

## D-V2: 途中で見つけたこと (niri のソースを読んだ結果)

niri の commit e19df12 (2026-10-21) の `niri-config/src/lib.rs` と `niri-config/src/output.rs` を読んだ。

- **`output` 節は、include をまたいで後から足される。** ある出力の設定を引くとき、niri は `Outputs::find` で最初に一致したものを使う (`self.0.iter().find(...)`)。したがって、`local.kdl` などの前の層に同じ出力の `output` 節があると、DMS の設定画面が書く `dms/outputs.kdl` は効かない。2画面 144Hz の設定はここに入るので、INT-1 に直接かかる。
- **`window-rule` も後から足される。** ただし、ウィンドウの規則は順に適用され、後のものが上書きする (`src/window/mod.rs` の `ResolvedWindowRules::compute`)。こちらは DMS が勝つ。
- **`binds` は、同じキーを後のものが置き換える。** そのほかの多くの節は、項目ごとに後のものが上書きする。

これを規則にして、全列挙で `DmsUiWriteAlwaysWins` を検査する。構成ファイルを作る段階5では、実際の KDL ファイルを入力にする。

## D-V3: Server への確認事項 (候補)

Tailscale の ACL は tailnet 全体の設定で、Desktop だけでは決められない。D-V3 の検査は、Desktop 側の設定 (待ち受けアドレスと nftables) と、「ACL がこうなっていること」という前提に分けて書く。ACL の前提は台帳の「Server への確認事項」に載せる。

## 道具の版

| 道具 | 版 | 確認 |
|---|---|---|
| TLA+ tools (TLC) | v1.7.4 (TLC 2.19)、`tla2tools.jar` の sha256 `936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88` | https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4 |
| statechart スクリプト | cursor/plugins の commit `8b3326d99fd4b993cb33a24dad8af03175c642c5` (2026-10-22) の `pstack/skills/statechart/scripts` | — |
| Node.js | 22 | — |
| Java | 21 (OpenJDK) | — |
| Mermaid の PNG 出力 | `npx @mermaid-js/mermaid-cli` (statechart が呼ぶ) | 版は D-V1 の確定時に固定する |

1コマンドでの再実行 (`verify/run.sh`) は、D-V1 の挙動に合意してから作る。中身は、jar の取得と sha256 の照合、statechart スクリプトの取得 (commit 固定)、D-V1〜D-V4 の実行、壊した版の実行。
