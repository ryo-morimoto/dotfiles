# 巻き戻し

更新で作業面が壊れても、別のマシンなしで、15分以内に直前の動いた状態へ戻れる。ブートメニューには、ログインできた状態のスナップショット (`desktop_good`) が必ず残っている。そのエントリを押し出すような更新は、pacman のフックが止める。

## Sub-features

- `good-entry-exists`: snapper に `desktop_good=yes` のスナップショットがある。
- `entries-below-esp`: `MAX_SNAPSHOT_ENTRIES` が数値で、ESP の使用率が `LIMIT_USAGE_PERCENT` 未満。
- `snap-pac-no-important`: snap-pac の `important_packages` / `important_commands` が無効。
- `guard-hook-installed`: 押し出しを止める pacman のフックが入っている。
- `drill`: 巻き戻し訓練。1つ前の `desktop_good` に戻し、15分以内に作業面に戻れたかを測る (月1回。desktop.md 6章)。

## How to get to it (user POV)

- 再起動し、Limine のメニューで「Snapshots」から `desktop_good` の付いたエントリを選ぶ。
- 起動したら、復元のラッパー (`desktop-restore`。段階5で作る) を実行して再起動する。
- 設定が新しい形式のままで作業面が壊れているときは、ホームの指定したパスを戻す (`desktop-restore --home`)。

## Driving it with dv

Preconditions:

- 実機か、btrfs + Limine の VM。代わりの環境 (namespace) では動かない。
- 作業中のデータを git に push してある (巻き戻しは /home の作業データを戻さないが、念のため)。

Steps:

- **設定の確認。** `docs/platform/desktop/functional/dv drive rollback` を実行する。`drill` 以外は自動である。
- **訓練の開始 (人の操作)。** `date -u +%FT%TZ > "$(dv evidence)/rollback/drill-start.txt"` を実行してから、`systemctl reboot` で再起動する。
- **エントリを選ぶ (人の操作)。** Limine のメニューで「Snapshots」を開き、`desktop_good` の付いた最新のエントリを選ぶ。メニューの画面を撮る。
- **復元する (人の操作)。** 起動したら、`desktop-restore` を実行し、再起動する。
- **終了を記録する。** ログインして作業面が上がったら、`date -u +%FT%TZ > "$(dv evidence)/rollback/drill-end.txt"` を実行する。開始からの差が15分以内なら pass で、`results.tsv` に手で `drill<TAB>pass<TAB>…分` を書く。
- **形式検証との突き合わせ。** 訓練の前後で `sudo snapper -c root list` と `/boot/limine.conf` の Snapshots の節を証拠に残す。D-V1 のモデルのとおりに、backup のエントリが1つ増えていることを確かめる。

## Gotchas

- `DV_RUN_ID` を固定しないと、訓練の開始と終了が別のフォルダに書かれる。訓練の間は `DV_RUN_ID` を export しておく。
- 訓練は、作業面が動いている状態から「わざと戻す」手順である (6章)。実際に壊れたときの手順も同じ。
- `desktop_good` が無い状態では、押し出しを止めるフックがすべての更新を止める (fail-closed)。このときは、ログインし直して印を作る。
- `drill` の時間には、ブートメニューを選ぶ人の時間が入る。15分を超えたら REL-1 の違反として台帳に記録し、ADR-0001 の切り替えトリガー (四半期に2回) で数える。
