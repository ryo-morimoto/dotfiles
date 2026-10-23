# B (Arch + decman + chezmoi + mise + btrfs + snapper) と B' (CachyOS) の事実 (取得日 2026-10-24)

## 候補の定義

- **B**: Arch Linux (公式リポジトリ core/extra)、宣言ツール decman (パッケージ、AUR、ファイル、systemd ユニット、ユーザー)、$HOME 側は chezmoi、言語ランタイムは mise。ファイルシステムは btrfs + snapper + snap-pac (pacman の前後でスナップショット)。ブートローダは snapper のスナップショットから起動できるもの (limine + limine-snapper-sync、または GRUB + grub-btrfs)。インストールは archinstall。
- **B'**: CachyOS (Arch 派生)。Arch の core/extra/multilib をそのまま残し、その上に CachyOS 独自のリポジトリ ([cachyos]、[cachyos-v3]、[cachyos-core-v3]、[cachyos-extra-v3]) を優先して置く構成。宣言ツール (decman など) は B と同じものを載せる前提で、ディストリ側の既定 (ファイルシステム、スナップショット、ブートローダ、NVIDIA) を調べた。

パッケージの所在は、archlinux.org の packages JSON API、AUR RPC v5、CachyOS ミラーの repo DB (`*.db`) を 2026-10-24 に直接読んで確認した。

## 事実

### 部品の入手経路 (FUN-1 / FUN-3 / SEC-3)

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| FUN-1 | niri は Arch 公式 **extra** にある (メンテナ dvzrv, alerque, Antiz。上流の作者ではなく Arch の Package Maintainer)。AUR には `niri-git` もある (メンテナ cosmo / FreeFull。上流の作者 YaLTeR とは名前が違う) | https://archlinux.org/packages/search/json/?name=niri 、https://aur.archlinux.org/rpc/v5/info?arg[]=niri-git | 確認済み |
| FUN-1 | DMS は Arch 公式 **extra** に `dms-shell` (メンテナ alerque) がある。上流は 2.0 で「Dux Shell」(リポジトリ duxlabs-dev/dux-shell) に名前を変え、Arch では新しいパッケージ `dux-shell` が **extra-testing** にある (`replaces=dms-shell`、`provides=dms-shell`)。つまり 2026-10-24 時点の extra は改名前の系列のまま | https://archlinux.org/packages/search/json/?name=dux-shell 、https://gitlab.archlinux.org/archlinux/packaging/packages/dux-shell/-/raw/main/PKGBUILD | 確認済み |
| FUN-1 | AUR の `dms-shell-git` はメンテナ bbedward、共同メンテナ Purian23。上流リポジトリのコミット数の1位と2位 (bbedward 3250、purian23 824) と名前が一致する (同一人物と判断。本人確認まではしていない) | https://aur.archlinux.org/rpc/v5/info?arg[]=dms-shell-git 、https://github.com/duxlabs-dev/dux-shell (git shortlog) | 確認済み (同一人物かは [推論]) |
| FUN-1 | 上流 DMS のドキュメントは「Arch では公式リポジトリ (extra) にあり、開発版は AUR にある」と書いている | https://duxlabs.dev/docs/dms/installation | 確認済み |
| FUN-1 | niri の Getting Started は Arch 向けに `dms-shell-niri` を pacman で入れる手順を載せているが、その名前のパッケージは公式リポジトリに無い (extra の dms-shell が `replaces=dms-shell-niri` で置き換えている)。上流ドキュメントが古い | https://github.com/niri-wm/niri/blob/main/docs/wiki/Getting-Started.md 、https://gitlab.archlinux.org/archlinux/packaging/packages/dms-shell/-/raw/main/PKGBUILD | 確認済み |
| FUN-1 | ghostty は Arch 公式 **extra** (メンテナ orhun, alerque, ptr1337)。AUR の `ghostty-git` は alerque が保守し、最初の登録者は gpanders (上流のメンテナと同名) | https://archlinux.org/packages/search/json/?name=ghostty 、https://aur.archlinux.org/rpc/v5/info?arg[]=ghostty-git | 確認済み |
| FUN-1 | zen-browser は Arch 公式リポジトリに **無い**。AUR の `zen-browser-bin` (メンテナ Larvey、共同 NextWorks、最初の登録者 ptr1337) が上流の GitHub リリースの tarball を再梱包する。上流の Linux 向けインストール文書が挙げるのは Flathub、tarball スクリプト、AppImage だけで、AUR には触れていない。上流 CODEOWNERS は mr-cheffy だけで、AUR メンテナは上流の人ではない | https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=zen-browser-bin 、https://docs.zen-browser.app/guides/install-linux 、https://github.com/zen-browser/desktop (CODEOWNERS) | 確認済み |
| FUN-1 | fcitx5-hazkey は Arch 公式に **無く**、AUR だけ (`fcitx5-hazkey`、`fcitx5-hazkey-bin`、`hazkey-zenzai-model`、メンテナはすべて hiira)。上流 (GitHub 7ka-Hiira、サイト hazkey.hiira.dev) の Arch 向け手順は AUR の `fcitx5-hazkey-bin` を推奨し、yay を使う。`-bin` は上流の GitHub リリースの tarball を取る。ソース版は Swift (約 3GB) が要り、Swift ヘッダを手で直す回避策がある | https://hazkey.hiira.dev/docs/install/archlinux 、https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=fcitx5-hazkey-bin | 確認済み (AUR メンテナ hiira が上流本人かは [推論]: AUR の URL が上流ドメインで名前も一致) |
| FUN-1 | fcitx5-mozc は Arch 公式 **extra** | https://archlinux.org/packages/search/json/?name=fcitx5-mozc | 確認済み |
| FUN-1 | niri の画面共有には `xdg-desktop-portal-gnome` が要る (niri パッケージの optdepends に「screencasting に必要」とある)。extra にある | https://archlinux.org/packages/search/json/?name=niri | 確認済み |
| FUN-1 / PERF-1 | niri 上流の NVIDIA 文書: NVIDIA ドライバが解放した VRAM をプールに返さない癖があり、niri が 1GiB 近く使うことがある。`/etc/nvidia/nvidia-application-profiles-rc.d/` に `GLVidHeapReuseRatio=0` のプロファイルを置いて回避する。画面共有のちらつきは niri 25.08 で修正済み | https://github.com/niri-wm/niri/blob/main/docs/wiki/Nvidia.md | 確認済み |
| FUN-1 | Arch の NVIDIA ページ: Wayland には DRM KMS が要る。`nvidia-utils` 560.35.03-5 以降は `nvidia_drm` の `modeset` と `fbdev` が既定で有効。555 より前、または Explicit Sync (`linux-drm-syncobj-v1`) に対応しないコンポジタではちらつきなどが出る | https://wiki.archlinux.org/title/NVIDIA | 確認済み |
| FUN-3 | `nvidia-open` (linux 用にビルド済み)、`nvidia-open-lts`、`nvidia-open-dkms`、`nvidia-utils`、`cuda`、`cudnn` は Arch 公式 **extra**。2025-12-20 のニュースで、590 から公式の `nvidia` が `nvidia-open` に置き換わった。Turing 以降 (RTX 3060 Ti = Ampere を含む) は手動介入なしで移行する | https://archlinux.org/news/nvidia-590-driver-drops-pascal-support-main-packages-switch-to-open-kernel-modules/ 、https://wiki.archlinux.org/title/NVIDIA | 確認済み |
| FUN-3 | Arch の NVIDIA ページは、Ampere 搭載の **ノート PC** で GSP ファームウェアにより完全に動かない事例を注記している (デスクトップの記載は無い) | https://wiki.archlinux.org/title/NVIDIA | 確認済み |
| FUN-3 | `ollama` と `ollama-cuda` は Arch 公式 **extra** (メンテナ svenstaro, lfleischer)。`ollama.service` が同梱される | https://archlinux.org/packages/extra/x86_64/ollama/files/json/ | 確認済み |
| FUN-3 | llama.cpp は Arch 公式 **extra** に `llama-cpp` という名前である (`llama.cpp` という名前では無い)。`llama-server` と `llama-server.service` を含む。CUDA は別パッケージ `ggml-cuda` (ggml の optdepends「CUDA backend」) で入れる。ggml は llama.cpp とは別の上流 (ggerganov/ggml) から別パッケージで作られている | https://archlinux.org/packages/extra/x86_64/llama-cpp/files/json/ 、https://archlinux.org/packages/search/json/?name=ggml | 確認済み |
| FUN-3 | AUR には `llama.cpp-cuda-git` (メンテナ Bink)、`llama.cpp-git` (lapsus) などがある。メンテナが上流 (ggml-org) の人かは確かめていない | https://aur.archlinux.org/rpc/v5/search/llama.cpp?by=name | 確認済み (所属は未検証) |
| FUN-2 / MNT-1 | chezmoi、mise、sbctl、snapper、snap-pac、grub-btrfs、limine、archinstall、btrfs-progs は Arch 公式 (core/extra) にある | https://archlinux.org/packages/search/json/?name=mise ほか | 確認済み |
| REL-1 | `limine-snapper-sync` と `limine-mkinitcpio-hook` は Arch では **AUR だけ** (メンテナ Zesko = 上流 gitlab.com/Zesko の作者)。`grub-btrfs` は extra。Arch wiki の Snapper ページも limine-snapper-sync を {{AUR}} として載せている。limine-snapper-sync の AUR ビルドは GraalVM (Java) を GitHub から取得してビルドする | https://aur.archlinux.org/rpc/v5/info?arg[]=limine-snapper-sync 、https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=limine-snapper-sync 、https://wiki.archlinux.org/title/Snapper | 確認済み |
| SEC-3 | B で AUR から入れる必要がある部品: fcitx5-hazkey(-bin)、zen-browser-bin (Flathub を使わない場合)、decman、limine-snapper-sync (limine を選ぶ場合)。それ以外の指定部品 (niri、dms-shell、ghostty、nvidia-open、cuda、ollama-cuda、llama-cpp + ggml-cuda、chezmoi、mise、snapper) は公式リポジトリ | 上の各行 | 確認済み |

### AUR の事件 (SEC-3)

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| SEC-3 | 2026-06-12 の Arch 公式ニュース「Active AUR malicious packages incident」: AUR で悪意のあるパッケージの引き取り (adoption) と更新が大量に起きている。新規アカウント作成、更新の push、引き取りや新規作成に支障が出る可能性がある。すべての PKGBUILD と install スクリプトの変更を読むよう呼びかけた | https://archlinux.org/news/active-aur-malicious-packages-incident/ | 確認済み |
| SEC-3 | 前兆 (2026-05-27、aur-general): 孤児になった `plex-media-player` を当日作られたアカウントが引き取り、`post_install()` で `npm install crypto-javascript` を走らせる変更を入れた。同じ内容の重複パッケージも新アカウントから上がった | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/BAWHLX4VFTT7JMQTTYTMG2URQFEZJV7Y/ | 確認済み |
| SEC-3 | 2026-06-15 (aur-general、Arch DevOps の Leonidas Spyropoulos): 悪意のあるパッケージの流入のため、AUR の新規アカウント登録を止めた | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/4JRS73YVTE7JUYHHE3ZDUIHXYHXZ3YQQ/ | 確認済み |
| SEC-3 | 2026-07-30 (aur-general、Arch DevOps の Robin Candau): 悪意のある引き取りと後続コミットが再び流入したため、パッケージの引き取りを止めた。同日、利用者から「build() の段階で 'validator' などの名前のバイナリを使う新しい波」の報告がある | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/DRDEU3JUSC72CB265XHXPFA3DFSLXPBP/ 、https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/IYRETAX4N5IGUV7JNNQIC7ZBYEDLHSJJ/ | 確認済み |
| SEC-3 | 8〜10月も aur-general に悪意のあるパッケージの報告が続いている (hyprland-fixes、xsnow、fsearch-bin、10-14 には yay/paru のタイポスクワットなど)。2026-10-15 の投稿 (利用者による。Arch スタッフの発言ではない) は「新規登録は数か月閉じたまま、再開の手順が示されていない」と書いている | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/2026/10/ 、https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/L7FYPMAMJOWCMXCCPHUFVQDJQT7TZX67/ | 確認済み (登録が今も止まっているかは公式の告知では未検証) |
| SEC-3 | 攻撃の型は「孤児パッケージの引き取り → install スクリプトや build() に悪意のある処理を入れる」。メンテナが上流本人で長く保守している AUR パッケージ (hazkey、decman、limine-snapper-sync、dms-shell-git) は、孤児化しない限りこの型に当たりにくい | 上の各スレッド | [推論] |

### decman (MNT-2 / INT-1 / INT-3 / FLX-2 / 道具の健全性)

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| 健全性 | 最終リリース **1.2.2 = 2026-07-04** (タグのコミット日)。最終コミットも同じ 2026-07-04。1.0.0 (2026-01-27) で「多くの破壊的変更」を伴う全面書き直しがあり、移行ガイドがある。それ以降の 1.1.0、1.2.0、1.2.1、1.2.2 は破壊的変更を告知していない | https://github.com/kiviktnm/decman/releases 、`git log` (https://github.com/kiviktnm/decman) | 確認済み |
| 健全性 | メンテナは実質1人 (Kivi Kaitaniemi / kiviktnm)。直近1年のコミット 86 件のうち 83 件が本人。AUR の `decman` も本人が保守 (投票 2)。公式リポジトリには無い | `git shortlog` (https://github.com/kiviktnm/decman) 、https://aur.archlinux.org/rpc/v5/info?arg[]=decman | 確認済み |
| 健全性 | 2026-10-24 時点で最終コミットから約3.5か月。付録 A.2 の切り替えトリガー「6か月更新が無い」にはまだ当たらない | 上と同じ | [推論] (日数の計算のみ) |
| FLX-1 / FLX-2 | 宣言は **Python** のソースファイル (`source.py`)。中身は集合で、`decman.pacman.packages`、`decman.aur.packages`、`decman.files`、`decman.directories`、`decman.symlinks`、`decman.systemd.enabled_units`、`decman.systemd.enabled_user_units`、`decman.flatpak.packages` を足していく。Module クラスでまとめられ、フック (on_enable、on_change、on_disable など) で任意のコマンドを走らせられる。source は root で実行される | https://github.com/kiviktnm/decman/blob/main/README.md 、https://github.com/kiviktnm/decman/blob/main/docs/README.md | 確認済み |
| FUN-1 | 管理できる対象: pacman パッケージ、AUR / 独自 PKGBUILD のパッケージ、Flatpak (既定は無効)、ファイル・ディレクトリ・シンボリックリンク (所有者、権限、変数置換つき)、systemd のシステムとユーザーのユニットの有効化、ユーザー / グループ / subuid、PGP 鍵 (extras モジュール) | https://github.com/kiviktnm/decman/blob/main/README.md 、https://github.com/kiviktnm/decman/blob/main/docs/extras.md | 確認済み |
| SEC-3 | AUR ヘルパーを **内蔵** している (外部の yay/paru は要らない)。devtools (`mkarchroot`、`makechrootpkg`) でクリーンな chroot の中でビルドし、ビルド済みは `/var/cache/decman/aur` に3版まで残す。ビルド前に PKGBUILD の全文か、前回レビューしたコミットからの差分を見せて確認を求める。作者自身が「AUR のビルドは主目的ではなく、ビルドできなければ ignored_packages に入れて自分でビルドせよ」と書いている | https://github.com/kiviktnm/decman/blob/main/docs/aur.md 、`plugins/decman-pacman/src/decman/plugins/aur/fpm.py` | 確認済み |
| MNT-2 | 適用は `sudo decman` 1回で差分適用 (`pacman -S --needed`、不要になったものは `pacman -Rs`、`systemctl enable/disable`)。再起動やイメージのビルドは要らない。systemd ユニットは **有効化だけで、起動・停止はしない**。`--dry-run` で事前に差分を表示できる。`--only files` などで段階を絞れる | https://github.com/kiviktnm/decman/blob/main/README.md 、`src/decman/app.py` | 確認済み |
| INT-3 | pacman / AUR プラグインは「明示的にインストールされたパッケージ」を宣言と一致させる。宣言に無い明示インストールは **削除** し、optdepends だけで残っている孤児も削除する。したがって `decman --dry-run` が、宣言されていないパッケージの一覧の役を果たす。パッケージグループとは相性が悪い (メタパッケージを使えと書いてある) | https://github.com/kiviktnm/decman/blob/main/docs/pacman.md | 確認済み |
| INT-3 | ファイルは decman が自分で作ったものだけを追跡し、宣言から消えたら削除する (ディレクトリは消さない)。decman が作っていない /etc の変更は一覧しない。Arch 側には `pacman -Qii` で「変更されたバックアップ対象ファイル」を、`pacman -Qlq` と find の差で「どのパッケージにも属さないファイル」を一覧する方法が wiki にある (aconfmgr はこれを道具にしたもの) | https://github.com/kiviktnm/decman/blob/main/docs/README.md 、https://wiki.archlinux.org/title/Pacman/Tips_and_tricks | 確認済み |
| INT-1 | decman の File は **コピー** で配置し、内容が違えば次の実行で上書きする (`shutil.copy`)。アプリが自分で書き換えたファイルを decman で宣言すると、次の `decman` で元に戻る。$HOME の GUI 設定は decman ではなく chezmoi 側 (または宣言しない) に置く必要がある | `src/decman/core/fs.py` (https://github.com/kiviktnm/decman) | 確認済み (挙動はソースから読んだ。実機では未検証) |
| MNT-2 | decman は pacman を呼ぶので、snap-pac がある環境では decman の pacman 段と aur 段のそれぞれで snapper の pre/post スナップショットが作られる | snap-pac の説明 (https://wiki.archlinux.org/title/Snapper) と decman の実行順 | [推論] |

### snapper / スナップショット / ブートローダ (REL-1 / REL-2)

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| REL-1 | Arch wiki Snapper: `@` (/) のスナップショットには別サブボリューム (例 `@home`、`@var_log`) は入らない。入れ子のサブボリュームも入らない。スワップファイルを含むサブボリュームはスナップショットできない | https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout | 確認済み |
| REL-1 | **/var の扱い**: wiki は /var/cache、/var/spool、/var/tmp、/var/lib/machines、/var/lib/docker、/var/lib/postgres などを別サブボリュームにすることを勧める。一方で **pacman のデータベース `/var/lib/pacman` はルートの `@` に残さなければならない**。ログ (/var/log) はスナップショットしないことを勧める (調査しやすくするため) | https://wiki.archlinux.org/title/Snapper | 確認済み |
| REL-1 | **読み取り専用スナップショットからの起動**: snapper のスナップショットは既定で読み取り専用で、多くのサービス (ディスプレイマネージャなど) は書き込める /var が無いと起動しない。回避は「スナップショットを書き込み可能にする」か「overlayfs で起動する (変更は RAM にだけ残る)」。grub-btrfs の overlayfs フックは busybox の initramfs 専用で、systemd の initramfs では動かない。grub-btrfs の README も「読み取り専用で使うなら /var/log か /var 全体を別サブボリュームにせよ」と書く | https://wiki.archlinux.org/title/Snapper#Booting_into_read-only_snapshots 、https://github.com/Antynea/grub-btrfs/blob/master/README.md | 確認済み |
| REL-1 | **/boot がスナップショットに入らない問題**: /boot が btrfs 以外 (ESP など) にあると snapper はバックアップできない。wiki は「System backup#Snapshots and /boot partition」のフックでカーネル更新時に /boot を btrfs のルートへコピーする方法を案内している。カーネルモジュール (`/usr/lib/modules`) は `@` に入るので、`@` だけ戻すと /boot のカーネルとモジュールの版がずれる | https://wiki.archlinux.org/title/Snapper#Backup_non-Btrfs_boot_partition_on_pacman_transactions | 確認済み (版ずれは [推論]。下の Limine の行が同じ前提を明記している) |
| REL-1 | **ロールバックの正式な手順** (wiki の推奨レイアウト `@`、`@home`、`@snapshots`、`@var_log` の場合): ライブ USB で起動 → subvolid=5 をマウント → `info.xml` の日時 (UTC) でスナップショット番号を探す → `@` を `@.broken` に移す → `btrfs subvolume snapshot /mnt/@snapshots/N/snapshot /mnt/@` → fstab が subvolid 指定なら書き換え → `@` に chroot して initramfs を作り直す → 再起動。wiki はこのレイアウトを「`snapper rollback` 用ではない」と明記している。自動化は AUR の `snapper-rollback` | https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot | 確認済み |
| REL-1 | wiki の Snapper ページの「Restore snapshot」節には Accuracy (正確さに疑問) の印が多数付いている (default layout の定義が曖昧、SLES の資料の流用など) | https://wiki.archlinux.org/title/Snapper#Restore_snapshot | 確認済み |
| REL-1 | **limine-snapper-sync** (Arch wiki Limine): ブートメニューから snapper のスナップショットを選んで起動でき、`limine-snapper-restore` で「対応するカーネル版も含めて」復元する。復元方式は rsync / replace (既定) / snapper (openSUSE 型レイアウト用)。復元後に「backup」エントリを作るので戻せる。スナップショットごとのカーネルと initramfs を ESP にコピーし、ハッシュで重複を省く | https://wiki.archlinux.org/title/Limine#Snapper_snapshot_integration_for_Btrfs 、https://gitlab.com/Zesko/limine-snapper-sync (README) | 確認済み |
| REL-1 | limine-snapper-sync の制約: ESP は **4GiB 以上** を推奨。NVIDIA と DKMS のモジュールは initramfs 1つあたり 200〜300MiB 以上増える。`/usr/lib/modules` はルートと同じサブボリュームに置く必要がある。導入前に作ったスナップショットには起動エントリを作れない。ESP の使用率が上限 (既定 85%) に達すると古いエントリを **警告なしに** 消す。sbctl の署名はハッシュが再現しないため重複が増える | https://wiki.archlinux.org/title/Limine 、https://gitlab.com/Zesko/limine-snapper-sync (README) | 確認済み |
| REL-1 | GRUB + grub-btrfs: grub-btrfsd がスナップショットの作成・削除を監視して GRUB メニューを作り直す。スナップショット内の `/boot` にあるカーネルと initramfs を自動で検出する (つまり /boot を btrfs の `@` に置けばカーネルもスナップショットに入る)。grub-btrfs は extra | https://github.com/Antynea/grub-btrfs/blob/master/README.md 、https://wiki.archlinux.org/title/Snapper | 確認済み |
| REL-1 | systemd-boot は ESP にカーネルを置く必要があるため、スナップショットからの起動は標準では無い (CachyOS wiki の比較) | https://wiki.cachyos.org/installation/boot_managers/ | 確認済み |
| REL-2 | 部品1つを戻す手段: pacman キャッシュから `pacman -U` で旧版を入れる、Arch Linux Archive (公式リポジトリの日次スナップショット) から入れる、`IgnorePkg` で更新を止める。ただし部分更新は非サポートで、依存も一緒に戻す必要が出ることがある (wiki の警告) | https://wiki.archlinux.org/title/Downgrading_packages 、https://wiki.archlinux.org/title/Pacman#Skip_package_from_being_upgraded 、https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported | 確認済み |
| REL-2 | archinstall の既定の btrfs レイアウトは `@`、`@home`、`@log` (/var/log)、`@pkg` (/var/cache/pacman/pkg)。pacman キャッシュがルートの外にあるので、`@` を戻しても旧版のパッケージファイルは残る | https://github.com/archlinux/archinstall/blob/master/archinstall/lib/disk/default_layouts.py | 確認済み (ロールバック後に残る点は [推論]) |
| REL-1 | 何が戻り何が戻らないか (B の典型レイアウト): 戻る = `/usr` (カーネルモジュールを含む)、`/etc`、`/var/lib` (pacman DB を含む)。戻らない = `/home`、`/var/log`、別サブボリュームにした `/var/cache` など、ESP 上の /boot (limine-snapper-sync を使わない場合)、NVRAM のブートエントリ、ファームウェア | 上の Snapper / Limine の行から整理 | [推論] |

### Secure Boot と NVIDIA (G-HW-7)

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| G-HW-7 | Arch の公式インストールイメージは **Secure Boot に対応していない** (2016 年以降)。インストール時は Secure Boot を無効にするか、イメージを作り直すか、Archboot を使う | https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Booting_an_installation_medium | 確認済み |
| G-HW-7 | wiki の手順 (sbctl): ファームウェアを Setup Mode にする → `sbctl create-keys` → `sbctl enroll-keys -m -f` (Microsoft と OEM の鍵も一緒に登録) → `sbctl verify` → `sbctl sign -s` でカーネルとブートローダに署名 → Secure Boot を有効に戻す。sbctl の pacman フックがカーネル・systemd・ブートローダの更新時に自動で署名し直す | https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Assisted_process_with_sbctl | 確認済み |
| G-HW-7 | GPU などのオプション ROM は Microsoft 3rd Party UEFI CA で署名されていることが多い。自分の鍵だけにすると機種によっては起動不能 (文鎮化) になる、と wiki が警告している。`-m` を付けて Microsoft の鍵を残すのが既定の手順 | https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Using_your_own_keys | 確認済み |
| G-HW-7 | **Arch の公式カーネルは Secure Boot で起動しても lockdown を自動で有効にしない** (wiki に明記)。カーネル設定は `CONFIG_MODULE_SIG_FORCE` 未設定、`CONFIG_LOCK_DOWN_KERNEL_FORCE_NONE=y`。したがって署名されていない外部モジュール (nvidia-open) もそのまま読み込める。shim / MOK を使わない sbctl 方式では MOK 登録は要らない | https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot 、https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/config.x86_64 | 確認済み (実機での読み込みは未検証) |
| G-HW-7 | Arch wiki の NVIDIA ページには Secure Boot との両立の専用節が無い。両立の根拠は上の「lockdown しない、署名を強制しない」から導くことになる | https://wiki.archlinux.org/title/NVIDIA | 確認済み (節が無いことを確認) |
| G-HW-7 | GRUB で Secure Boot (自前の CA 鍵) を使う場合は `grub-install ... --modules="tpm" --disable-shim-lock` が必要 | https://wiki.archlinux.org/title/GRUB#Secure_Boot_support | 確認済み |
| G-HW-7 | Limine は 11.2.0 以降、Secure Boot が有効だと設定ファイルの BLAKE2B チェックサムの登録と、全ファイルパスへのハッシュ付記を強制する (無いと panic)。`limine-enroll-config` が sbctl で Limine の EFI バイナリに署名する。wiki は「設定を変えて再登録を忘れると起動できなくなり、Secure Boot を切っても直らないので、署名・登録をしない予備のブートローダを用意せよ」と警告している | https://wiki.cachyos.org/configuration/secure_boot_setup/ 、https://wiki.archlinux.org/title/Limine | 確認済み |

### 無人インストール (FLX-3 / SAF-1)

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| FLX-3 | archinstall は `--config <file.json>` か `--config-url <URL>` で全設定を渡せる。パスワード類は別ファイル `--creds`。`silent: true` で質問を出さない。`archinstall --dry-run` で現在の選択を設定ファイルとして書き出せる。設定には disk_config、bootloader_config (Systemd-boot / grub / limine、UKI)、kernels、packages、profile、custom_commands (インストール後に chroot 内で実行) などがある | https://github.com/archlinux/archinstall/blob/master/docs/installing/guided.rst 、https://github.com/archlinux/archinstall/blob/master/docs/cli_parameters/config/config_options.csv | 確認済み |
| FLX-3 | archinstall は btrfs の snapshot_config に Snapper / Timeshift を選べる。Snapper を選ぶと `root` と `home` の設定を作り、timeline と cleanup のタイマーを有効にする。ブートローダが GRUB のときだけ grub-btrfs と grub-btrfsd を入れる。**limine を選んでも limine-snapper-sync は入れない** (AUR のため) | https://github.com/archlinux/archinstall/blob/master/archinstall/lib/installer.py | 確認済み |
| FLX-3 | archinstall は GPU ドライバの選択肢に「Nvidia (open kernel module for newer GPUs, Turing+)」= nvidia-open-dkms を持つ | https://github.com/archlinux/archinstall/blob/master/archinstall/lib/hardware.py | 確認済み |
| SAF-1 | archinstall の disk_config の `device` は `/dev/sda` のような名前で書く例になっている。読み込み時は検出したデバイスの辞書をそのパスで引き、見つからなければ **黙ってその項目を飛ばす**。`/dev/disk/by-id/...` を書いた場合に一致するかは確かめていない | https://github.com/archlinux/archinstall/blob/master/archinstall/lib/models/device.py (parse 部) | [推論] (ソースを読んだだけ。実機未検証) |

### 定常の保守 (MNT-4 / MNT-5)

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| MNT-4 | Arch wiki System maintenance: 更新の前に archlinux.org のニュース (RSS か arch-announce) を読むことが期待されている。pacman の指示を超える手動介入が要るときはニュースが出る。`informant` (公式 extra) などの pacman フックで、未読ニュースがあると更新を止められる。`pacman -Sy` だけの実行 (部分更新) は非サポート | https://wiki.archlinux.org/title/System_maintenance | 確認済み |
| MNT-4 | 直近12か月 (2025-10-24〜2026-10-24) の Arch 公式ニュースは 13 件。うち題名に「manual intervention」「breaking changes」が付くものは 7 件 (dovecot、waydroid、.NET、kea、varnish、virtualbox-ext-vnc、mkinitcpio TPM2)。ほかに NVIDIA 590 (Pascal 以前だけ要介入)、iptables の nft 既定化、AUR 事件、セキュリティ更新2件、選挙結果 | https://archlinux.org/news/ | 確認済み |
| MNT-4 | 上の 7 件のうち、この Desktop 構成 (G-HW、P) に関係しそうなのは mkinitcpio TPM2 (TPM2 で LUKS を解錠している場合だけ) くらい。NVIDIA 590 は Ampere では介入不要 | 上と同じ | [推論] |

### B' CachyOS

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| FLX-2 | CachyOS は Arch の core/extra/multilib を pacman.conf に残したまま、その **上に** 独自リポジトリを置く (「Arch のリポジトリより上に置け」と文書が明記)。x86-64-v3 の CPU では `[cachyos-v3]`、`[cachyos-core-v3]`、`[cachyos-extra-v3]`、`[cachyos]` を使う。導入時に CachyOS 版の `pacman` も入れる | https://wiki.cachyos.org/features/optimized_repos/ | 確認済み |
| G-HW-1 | `-v3` リポジトリは Arch のパッケージを x86-64-v3 向けに再コンパイルしたもの (文書は 5〜20% の性能向上と書く)。2026-10-24 の repo DB では `[cachyos-extra-v3]` が 7404 件、Arch の pkgrel に `.1` などを付けた再ビルドになっている (例: niri、ghostty、llama-cpp、ggml-cuda、ollama-cuda、nvidia-open、snapper、sbctl、mise) | https://mirror.cachyos.org/repo/x86_64_v3/cachyos-extra-v3/cachyos-extra-v3.db 、https://wiki.cachyos.org/features/optimized_repos/ | 確認済み |
| SEC-3 | CachyOS の `[cachyos]` リポジトリは、Arch では AUR にしか無いものを一部ビルド済みで配る: `zen-browser-bin`、`limine-snapper-sync`、`limine-mkinitcpio-hook`、`limine-entry-tool`、`paru`、`yay`、独自の `dms-shell`。**fcitx5-hazkey と decman は無い** (AUR のまま) | https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos.db | 確認済み |
| SEC-3 | 第三者ビルドの経路が1つ増える (CachyOS のビルド基盤と鍵 F3B607488DB35A47)。そのぶん AUR から入れる数は減る。CachyOS のリポジトリを他の Arch 派生ディストリで再配布することは禁止、Arch の利用者が使うことは認めている | https://wiki.cachyos.org/policy/repository_policy/ 、https://wiki.cachyos.org/features/optimized_repos/ | 確認済み |
| REL-1 | **既定のファイルシステムは btrfs** (zstd レベル3の圧縮)。サブボリュームは `@` (/)、`@home`、`@root`、`@srv`、`@cache` (/var/cache)、`@tmp` (/var/tmp)、`@log` (/var/log) | https://wiki.cachyos.org/installation/filesystem/ | 確認済み |
| REL-1 | **既定のブートローダは Limine** (GUI インストーラ Calamares の `packagechooser_bootloader.conf` が `default: limine`、`bootloader.conf` も `efiBootLoader: "limine"`)。選択肢は Limine、systemd-boot、GRUB、rEFInd。Limine の snapper 連携 (limine-snapper-sync) は「btrfs なら既定で有効」。インストーラは limine-snapper-sync のために boot パーティションを 4192MB にした | https://github.com/CachyOS/cachyos-calamares (branch cachyos、src/modules/packagechooser/packagechooser_bootloader.conf) 、https://wiki.cachyos.org/installation/boot_managers/ 、https://wiki.cachyos.org/cachyos_basic/changelogs/gui_installer/ | 確認済み |
| REL-1 | snap-pac が既定で入り、pacman の前後でスナップショットを取る。`cachyos-snapper-support` は `root` の snapper 設定だけを作り (home は作らない)、timeline は無効、cleanup タイマーを有効にする。GRUB を選ぶ場合は `grub-btrfs-support` で GRUB メニューに出す。CachyOS wiki は「スナップショットはブートローダの故障とハードの故障には役立たない」と書く | https://wiki.cachyos.org/configuration/btrfs_snapshots/ 、https://github.com/CachyOS/CachyOS-PKGBUILDS/tree/master/cachyos-snapper-support | 確認済み |
| FUN-3 | NVIDIA はハードウェア検出ツール `chwd` が入れる。プロファイル `nvidia-open-dkms` は nvidia-utils、egl-wayland、opencl-nvidia、libva-nvidia-driver などを入れ、カーネルが linux-cachyos 系なら **ビルド済みモジュール `linux-cachyos-nvidia-open`** を、そうでなければ nvidia-open-dkms を選ぶ。`nvidia-utils` と `nvidia-open-dkms` は CachyOS 自身のリポジトリで配布され、Arch extra のものより優先される。別プロファイル `nvidia-ai-sdk` が cuda、cudnn、nccl、ollama-cuda、pytorch などをまとめて入れる | https://github.com/CachyOS/chwd/blob/master/profiles/pci/graphic_drivers/profiles.toml 、https://github.com/CachyOS/chwd/blob/master/profiles/pci/ai_sdk/profiles.toml 、https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos.db | 確認済み |
| FUN-3 | Arch 公式の nvidia-open / nvidia-utils / ghostty の共同メンテナに ptr1337 がいる。CachyOS の FAQ は ptr1337 を CachyOS の創設者の1人と書いている (Arch と CachyOS の NVIDIA 系パッケージに同じ人が関わっている) | https://archlinux.org/packages/search/json/?name=nvidia-open 、https://wiki.cachyos.org/cachyos_basic/faq/ | 確認済み |
| G-HW-7 | linux-cachyos の設定も `CONFIG_MODULE_SIG_FORCE` 未設定、`CONFIG_LOCK_DOWN_KERNEL_FORCE_NONE=y` (Arch と同じく署名の無いモジュールを読み込める) | https://github.com/CachyOS/linux-cachyos/blob/master/linux-cachyos/config | 確認済み |
| G-HW-7 | CachyOS wiki の Secure Boot 手順は sbctl を使う (Setup Mode → `sbctl create-keys` → `sbctl enroll-keys --microsoft --firmware-builtin`、ASUS / Gigabyte では `--firmware-builtin` を付けない)。Limine は 11.2.0 以降、設定のチェックサム登録が必須 (`ENABLE_ENROLL_LIMINE_CONFIG=yes`)。インストーラの変更履歴に `sbctl-batch-sign` スクリプトがある | https://wiki.cachyos.org/configuration/secure_boot_setup/ 、https://wiki.cachyos.org/cachyos_basic/changelogs/gui_installer/ | 確認済み |
| FUN-1 | CachyOS のインストーラは Niri をデスクトップの選択肢に持ち (`cachyos-niri-settings`、`cachyos-niri-noctalia`)、`dms-shell` を自前のリポジトリでも配る | https://wiki.cachyos.org/cachyos_basic/changelogs/gui_installer/ 、https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos.db | 確認済み |
| MNT-4 | CachyOS 26.06 のインストーラは paru を既定のインストールから外し、GUI/CLI のパッケージマネージャ Shelly を勧めている。CachyOS 版 pacman は scriptlet とフックのネットワーク隔離を追加した | https://wiki.cachyos.org/cachyos_basic/changelogs/gui_installer/ | 確認済み |

## 未検証のまま残したこと

- decman を実機で走らせたときの挙動 (ファイル上書き、AUR の chroot ビルドの所要時間、snap-pac との組み合わせ)。ソースと文書だけで判断した。
- `/dev/disk/by-id/...` を archinstall の disk_config に書いたときに一致するか (SAF-1)。ソースからは一致しない可能性がある [推論]。
- AUR の新規登録と引き取りの停止が 2026-10-24 時点でも続いているか。公式の再開告知は見つけていない (10-15 の利用者の投稿は「閉じたまま」と書いている)。
- AUR メンテナ hiira (hazkey)、bbedward / Purian23 (dms-shell-git) が上流本人であることの本人確認。名前と URL の一致から判断した。
- `zen-browser-bin` の AUR メンテナ (Larvey / NextWorks) と上流の関係。上流の文書と CODEOWNERS には名前が無い。
- `llama.cpp-cuda-git` などの AUR メンテナと上流 (ggml-org) の関係。
- CachyOS のライブ ISO が Secure Boot 有効のまま起動できるか。CachyOS wiki は導入後の手順だけを書いている。
- CachyOS で無人インストール (設定ファイル指定) ができるか。Calamares / CLI インストーラの文書に該当する記述は見つからなかった。CachyOS の上で archinstall を使うことの公式な扱いも未検証。
- CachyOS のリポジトリが Arch に対してどれだけ遅れるか (鮮度の数値はブリーフにより対象外)。
- limine-snapper-sync で復元したとき、ESP 外 (NVRAM、ファームウェア) と別サブボリューム (@home、@log、@cache) がどう扱われるかを実機で確かめていない。
- NVIDIA + niri + DMS の組み合わせで、niri 文書の VRAM の問題以外に既知の不具合があるか (DMS の文書は NVIDIA に触れていない)。
- `snapper rollback` (openSUSE 型) を Arch で使う構成の詳細。Arch wiki は推奨レイアウトを `snapper rollback` 用ではないとしている。
