---
id: ADR-0002
status: accepted
satisfies: [REL-2, REL-5]
partial: [REL-1]
not_satisfied: []
---

# ADR-0002: 更新と巻き戻しは btrfs + snapper + Limine + limine-snapper-sync

日付: 2026-10-24。状態: 承認 (2026-10-24)。

## 改訂

| 日付 | 内容 |
|---|---|
| 2026-10-24 | `@home` にもスナップショットを取り、指定したパスだけを戻す手順を足した (決定 7)。1つ前の推論イメージを残す規則を足した (決定 8)。理由: 「更新は /home を書き換えない」という前提が成り立たないため。アプリは更新後の初回起動でユーザー設定を新しい形式に移すことがある (例: DMS 2.0 は設定の場所を `DankMaterialShell` から `dms` に移す)。移行が一方通行だと、ルートだけを戻しても旧版が新しい形式の設定を読めず、作業面が壊れたままになる |
| 2026-10-24 | D-V1 (TLA+) の結果を受けて、決定 9〜13 を足した。limine-snapper-sync は `MAX_SNAPSHOT_ENTRIES` を超えた起動エントリを、important を見ずに古い順に消す (`SnapshotManager.java`)。そのため「壊れたまま更新を重ねる」と、動いた状態のエントリが押し出された。ユーザーが承認 |

## 文脈

- 鮮度を上に置いた (Q1) ので、更新で壊れる回数は増えると見込む [推論]。REL-1 (別マシンなしで15分以内に直前の動作状態へ戻る) は MUST のまま残っている。
- Arch wiki の正式なロールバック手順は、ライブ USB で起動してサブボリュームを差し替え、chroot で initramfs を作り直すものである。これは「別マシンなし」は満たすが、15分に収まる保証が無い。
- /boot が ESP にあると snapper のスナップショットに入らない。ルートだけ戻すと、カーネルとモジュールの版がずれる (wiki)。

## 決定

1. **ファイルシステム:** NVMe のルートを btrfs にする。サブボリュームは次のとおり。

   | サブボリューム | マウント先 | 戻すか |
   |---|---|---|
   | `@` | `/` | 戻す |
   | `@home` | `/home` | 全体は戻さない。指定したパスだけ戻す (決定 7) |
   | `@log` | `/var/log` | 戻さない (調査用) |
   | `@pkg` | `/var/cache/pacman/pkg` | 戻さない (旧版の入れ直しに使う) |
   | `@containers` | `/var/lib/containers` | 戻さない (推論イメージとモデル。ADR-0003) |
   | `@snapshots` | `/.snapshots` | — |

   pacman の DB (`/var/lib/pacman`) は wiki の指示どおり `@` に残す。
2. **スナップショット:** snapper (root の設定だけ) と snap-pac を使う。pacman の前後で自動で取る。decman は pacman を呼ぶので、decman で適用したときも取られる [推論。D-V1 と機能テストで確かめる]。
3. **ブートローダ:** Limine と limine-snapper-sync (AUR、上流の作者が保守) を使う。ブートメニューからスナップショットを選んで起動でき、`limine-snapper-restore` が対応するカーネルも一緒に戻す。
4. **ESP:** 4GiB 以上にする (limine-snapper-sync の推奨。NVIDIA のモジュールで initramfs が 200〜300MiB 増える)。NVMe 1TB から割り当てる。
5. **部品1つだけ戻す (REL-2):** `@pkg` のキャッシュか Arch Linux Archive から `pacman -U` で旧版を入れ、decman の宣言で `IgnorePkg` 相当に固定する。推論ランタイムはイメージのダイジェストを1つ前に戻す (ADR-0003)。
6. **HDD 2TB:** 起動に必要なものを置かない。`nofail` でマウントする (REL-5)。
7. **ユーザー設定の巻き戻し:**
   - snapper に `home` の設定を足す。snap-pac で、pacman の前後に root と同時にスナップショットを取る。
   - `/home` 全体は戻さない。スナップショットより後の作業が消えるからである (REL-4)。
   - 壊れたときは、アプリが自分で書き換える設定のパスだけを `snapper -c home undochange <pre>..<post> <パス>` で戻す。
     - パスの一覧は宣言に置く (`rollback/home-paths.txt`)。例: `~/.config/niri/dms/`、`~/.config/dms/`、`~/.config/DankMaterialShell/`。
     - chezmoi で宣言した設定は一覧に入れない。`chezmoi apply` で戻るからである。
   - 手順はルートの復元と合わせて15分に収める (REL-1)。
8. **推論イメージ:** 宣言で指しているイメージに加えて、1つ前のダイジェストのイメージを `@containers` に残す (prune の対象から外す)。ルートを戻すとイメージの指定も1つ前に戻るので、ネットワークなしでそれを起動できるようにする。
9. **動いた印 (D-V1 の a):** ログインできたら、ユーザーのサービスがそのときの状態のスナップショットを作り、userdata に `important=yes` と `desktop_good=yes` を付ける (cleanup の方式は number)。
10. **押し出しを止めるフック (D-V1 の b):** pacman の PreTransaction フック (`AbortOnFail`) で、更新すると最新の `desktop_good` の起動エントリが `MAX_SNAPSHOT_ENTRIES` で押し出される場合に、更新を止める。該当するエントリが無ければ止める (fail-closed)。止まったら、再起動してログインし直す。
    - あわせて、decman の1回の実行で取るスナップショットを、pre / post の1組にまとめる。押し出しまでにできる更新の回数を増やすためである。方法は段階5で確かめる。
11. **復元のラッパー (D-V1 の c):** 復元は `desktop_good` の付いたスナップショットからだけ行う。ラッパーのスクリプトが、印の無いものを拒む。
12. **件数の上限 (D-V1 の d):** `MAX_SNAPSHOT_ENTRIES` は数値で決める (`auto` にしない)。値は ESP に `LIMIT_USAGE_PERCENT` 未満で収まるエントリの数より小さくする。値は段階4で、ESP の使用量を測って決める。
13. **snap-pac の `important_packages` と `important_commands` は無効のまま** (既定値) にする (D-V1 の e)。

## 満たす制約

| ID | どう満たすか | 根拠 |
|---|---|---|
| REL-2 | 旧版のパッケージファイルは `@pkg` に残る。推論はイメージ単位で戻せる | wiki.archlinux.org/title/Downgrading_packages |
| REL-5 | HDD は起動に必須のマウントに含めない (`nofail`) | — |

## 満たせない制約と妥協

| ID | 満たせない部分 | 妥協の理由と手当て |
|---|---|---|
| REL-1 (部分) | (1) `/home` の一覧に無いパス、`/var/log`、NVRAM、ファームウェアは戻らない。(2) ESP の使用率が上限 (既定 85%) に達すると、limine-snapper-sync は古いエントリを警告なしに消す。(3) 読み取り専用のスナップショットから起動したときに、サービスがどう動くかは実機で確かめていない。(4) 15分に収まるかは計測していない。(5) アプリが一覧に無い場所の設定を一方通行で移すと、戻せない | (1) は意図どおりで、作業データは git / Server へ置く (REL-4)。(2) は ESP を広く取り、機能テストで「直前のスナップショットのエントリがあること」を毎回確かめる。(3) と (4) は D-V1 (形式検証) と月1回の巻き戻し訓練 (6章) で確かめる。15分を超えた事例は REL-1 の違反として数える。(5) は、起きたらそのパスを一覧に足す。D-V1 のモデルに「ユーザー設定の移行」を状態として入れる |

## トレードオフ

- **得るもの:** ブートメニューから戻せること (別マシンもライブ USB も要らない)。カーネルも揃えて戻ること。
- **失うもの:**
  - ESP を 4GiB 取る。
  - `@home` のスナップショットが容量を使う (CoW なので差分の分だけ)。snapper の cleanup で古いものを消す。
  - 巻き戻しの手順に、`home` の部分的な復元が1手加わる。
  - 決定 10 により、ログインしてから次に再起動・ログインするまでにできる更新の回数に上限ができる (MNT-2 に影響)。回数は ⌈`MAX_SNAPSHOT_ENTRIES` ÷ (1回の実行で取るスナップショットの数)⌉ − 1 回。ユーザーが承認 (2026-10-24)
  - limine-snapper-sync は AUR で、ビルドに GraalVM (Java) を取ってくる。
  - Secure Boot を有効にすると、Limine 11.2 以降は設定のチェックサムを登録しないと panic する (ADR-0007)。
- **選ばなかった案:**
  - GRUB + grub-btrfs (どちらも extra): 読み取り専用スナップショットからの起動に overlayfs のフックが要る。そのフックは busybox の initramfs 専用で、復元は手作業になる。15分の保証が弱い。
  - systemd-boot: スナップショットからの起動が標準には無い。

## 切り替えトリガー

| 条件 | 切り替え先 |
|---|---|
| limine-snapper-sync が AUR で孤児になる、またはビルドできない状態が2週間続く | GRUB + grub-btrfs (公式) に移り、復元の手順を D-V1 で検証し直す |
| REL-1 の違反が四半期に2回 | ADR-0001 のトリガーで C (NixOS) へ |

## 検証

- D-V1: `verify/d-v1/model/Rollback.tla` で `NoWayBack` (= handoff の `AlwaysAWorkingStateReachable`) と `UpdatesStayPossible` を検査する。決定 9〜13 を外した版が失敗することも確かめる (`verify/run.sh`)。
- 機能テスト `drive/rollback-drill`: 壊れた更新をわざと入れ、ブートメニューから戻るまでの時間を測る。まず VM で行い、代用と明記する (段階4)。
