---
id: ADR-0001
status: proposed
satisfies: [FUN-1, FUN-2, MNT-2, MNT-3, FLX-2, INT-3]
partial: [MNT-1, MNT-4, SEC-3, MNT-5]
not_satisfied: []
---

# ADR-0001: OS は Arch Linux、システムの宣言は decman

日付: 2026-10-24。状態: 提案。採点は [`../candidates.md`](../candidates.md)。

## 文脈

- Q1 で MNT-1 (鮮度、N = 3日) を REL-1 (戻れること) より上に置いた。
- 鮮度の実測 (`research/snapshots/freshness-2026-10-23.md`) で、配布の経路だけで指定部品をすべて3日以内に揃えられる候補は無かった。指定部品が最も多く揃うのは Arch と CachyOS で、CachyOS の版は Arch と同じ日か1日遅れだった。
- MNT-2 (全体を再構築せずに分単位で適用) で、イメージを作り直して再起動する A (bootc) は × だった。NixOS (C) は毎回全体を評価し直すので △ だった。

## 決定

1. **OS は Arch Linux** で、公式リポジトリ (core / extra) を使う。CachyOS のリポジトリは足さない。
2. **システムの宣言は decman** で書く。対象は pacman のパッケージ、AUR のパッケージ、Flatpak、/etc などのファイル、有効にする systemd ユニット。宣言は dotfiles リポジトリに置く。
3. **AUR は許可リスト制**にする。載せるのは、上流の作者本人が保守していて、上流が Arch での入手先として案内しているものだけ。

   | AUR パッケージ | 理由 |
   |---|---|
   | `fcitx5-hazkey-bin` | 上流の Arch 向け手順がこれを勧めている。メンテナ hiira は上流 (hazkey.hiira.dev) と同名 |
   | `decman` | 上流の作者 kiviktnm が保守している |
   | `limine-snapper-sync` | 上流の作者 Zesko が保守している (ADR-0002) |

4. **zen は Flathub から入れる** (decman の Flatpak 管理を使う)。上流の Linux 向け手順は Flathub を第一に挙げている。AUR の `zen-browser-bin` はメンテナが上流の人ではないので使わない。
5. **DMS は extra から入れる**。2026-10-23 時点では `dms-shell` が 1.6.3 で、上流で改名した `dux-shell` 2.0.0 が extra-testing にある。
6. **推論ランタイムは OS のパッケージから入れない** (ADR-0003)。llama.cpp と ollama は鮮度の超過が多かった部品で、これを OS の更新から切り離す。

## 満たす制約

| ID | どう満たすか | 根拠 |
|---|---|---|
| FUN-1 | niri、dms-shell、ghostty、fcitx5-mozc、xdg-desktop-portal-gnome は extra にある。hazkey は上流が勧める AUR、zen は上流が勧める Flathub から入れる | facts-arch: archlinux.org packages API、hazkey.hiira.dev/docs/install/archlinux、docs.zen-browser.app/guides/install-linux |
| FUN-2 | 開発ツールは mise (extra) と公式パッケージで入れる。エージェント CLI は mise か各上流の配布物を使う (ADR-0004) | archlinux.org packages API |
| MNT-2 | `sudo decman` 1回で差分だけを適用する。中身は `pacman -S --needed`、不要になったものの削除、`systemctl enable/disable`。再起動もイメージのビルドも要らない | github.com/kiviktnm/decman README |
| MNT-3 | decman の宣言 (Python) と chezmoi の source を dotfiles リポジトリの1か所に置く | — |
| FLX-2 | decman の宣言は、パッケージ名・ファイル・有効にするユニットの集合である。他の手段の一覧へ機械的に移せる | decman README、docs/README.md |
| INT-3 | 宣言に無いパッケージは `decman --dry-run` が削除候補として出す。/etc の変更と、どのパッケージにも属さないファイルは、`pacman -Qii` と `pacman -Qlq` を使う一覧スクリプトで出す (段階4で作る) | decman docs/pacman.md、wiki.archlinux.org/title/Pacman/Tips_and_tricks |

## 満たせない制約と妥協

| ID | 満たせない部分 | 妥協の理由と手当て |
|---|---|---|
| MNT-1 (部分) | 過去180日に3日を超えたことがある: cuda 1回 (7日)、ollama-cuda 1回 (5日)、llama-cpp 1回 (5日)。2026-10-23 時点では llama-cpp が8日遅れ、DMS は改名のため extra で3日目 | 計測した候補の中で超過は最も少ない。超過が多かった推論ランタイムは ADR-0003 で OS から切り離す。DMS は切り替えトリガー (下記) で AUR の `dms-shell-git` (上流の開発者が保守) に移す。超過は `research/freshness.py` で毎週数える |
| MNT-4 (部分) | 週15分のうち、Arch のニュースを読む時間と、AUR の PKGBUILD の差分を読む時間が要る | 公式ニュースは直近12か月で13件。そのうち手動介入を告知したのは7件で、この構成に関係しそうなのは1件だった。`informant` (extra) で未読ニュースがあれば更新を止める。AUR は許可リストの3件だけにし、decman がビルド前に差分を見せる |
| SEC-3 (部分) | AUR には 2026-06 から悪意のあるパッケージの流入が続いている (孤児パッケージの引き取りによるもの) | 許可リストは上流の作者本人が保守するものだけにした。この攻撃の型には当たりにくい [推論]。decman は chroot でビルドし、PKGBUILD の差分を確認させる。許可リストのパッケージが孤児になったら、使うのをやめる |
| MNT-5 (部分) | NVIDIA の VRAM 対策 (`GLVidHeapReuseRatio=0`) は長く残る回避策である。上流は NVIDIA が取り込む見込みは小さいと書いている | どの手段でも同じ。decman の宣言に理由と出典を書いて残す |

## トレードオフ

- **得るもの:** 鮮度、差分の即時適用、手段に依存しない宣言の形 (FLX-2)。
- **失うもの:**
  - Nix で積んだ熟練 (G-PPL-2) を使わない。
  - システム全体を世代で戻すことはできない。巻き戻しはファイルシステムのスナップショットで代える (ADR-0002)。
  - decman の保守者は実質1人である (最終リリースは 1.2.2、2026-07-04)。
- **CachyOS を選ばない理由:**
  - 版は Arch と同じ日か1日遅れで、鮮度は上がらない (実測)。
  - その一方で、全パッケージの入手元に第三者のビルド基盤と鍵が加わる (SEC-3)。
  - 無人インストールの仕組みが確認できなかった (FLX-3)。
  - 利点の Limine + limine-snapper-sync の既定構成は、Arch でも AUR (上流の作者) で組める。

## 切り替えトリガー

| 条件 | 切り替え先 |
|---|---|
| REL-1 の違反 (15分以内に戻れない) が四半期に2回 | C (NixOS) を制約 v3 で作り直す |
| decman が6か月更新されない、または破壊的変更に追従できない | metapac か aconfmgr (宣言はパッケージ名とファイルの集合なので移せる) |
| extra の遅れによる DMS の MNT-1 違反が3回 | AUR の `dms-shell-git` (上流の開発者 bbedward が保守)。許可リストに足す |
| 許可リストの AUR パッケージが孤児になる、またはメンテナが代わる | そのパッケージの使用をやめ、代わりの経路を本文の制約で評価し直す |
| 保守時間の記録が4週続けて週15分を超える | 更新の頻度を下げることを検討する (MNT-1 と MNT-4 の優先順位は4章のとおり) |

## 検証

- MNT-1: `research/freshness.py` を週1回実行し、N 日を超えた回数を台帳に残す。
- MNT-2: 機能テスト `drive/declare-apply` で、パッケージを1つ足してから使えるまでの時間を測る (段階4)。
- INT-3: 機能テスト `doctor/undeclared-state` で、出力が空か、既知のものだけであることを確かめる (段階4)。
