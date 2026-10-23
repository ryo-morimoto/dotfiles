# C: NixOS (nixos-unstable) + Home Manager の事実 (取得日 2026-10-24)

## 候補の定義

- OS: NixOS、nixpkgs は `nixos-unstable` (調べた時点の commit `02c087f3fe673c9e317f206a627cb6b910336dbe`、2026-10-20)。宣言は flake 1つ (git)。ユーザー設定は Home Manager (nix-community/home-manager)。
- 鮮度が要る部品は、上流の flake か nixpkgs から入れる: niri、DMS (DMS 2.0 から名前が "Dux Shell" に変わった)、fcitx5-hazkey、NVIDIA ドライバ (open カーネルモジュール)、推論ランタイム (llama.cpp / ollama の CUDA 版)。
- CUDA 系はビルド済みバイナリのキャッシュ (cache.nixos-cuda.org か cache.flox.dev) から取る。
- Secure Boot は lanzaboote、無人インストールは disko + nixos-anywhere (または disko-install) を想定した。
- 調べ方: wiki.nixos.org の raw ソース、nixpkgs / home-manager / lanzaboote / disko / nixos-anywhere / niri / niri-flake / DMS / nix-hazkey / zen-browser-flake を `git clone --depth 1` して読んだ。nixpkgs は上の commit で `nix eval` してストアパスを出し、3つのキャッシュ (cache.nixos.org / cache.nixos-cuda.org / cache.flox.dev) に `.narinfo` があるかを HTTP で確かめた。

## 事実

### FUN-1: 部品の入手経路と、NVIDIA + Wayland + niri

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| FUN-1 | niri は nixpkgs に入っている (`pkgs/by-name/ni/niri`、NixOS モジュール `programs.niri`)。nixos-unstable の `niri` は cache.nixos.org から取れる (narinfo 200)。nixpkgs のモジュールは portal (gnome/gtk)、gnome-keyring、`systemd.user.services.niri.restartIfChanged = false` を設定する | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/modules/programs/wayland/niri.nix | 確認済み |
| FUN-1 | NixOS wiki によると、niri は「custom flake を入れなくても有効にできる」。niri-flake が要るのは、ごく新しい版を使いたいときか、設定を Nix 言語で書きたいときだけ | https://wiki.nixos.org/wiki/Niri | 確認済み |
| FUN-1 | niri 本体のリポジトリ (現在は niri-wm/niri) にも flake.nix がある。ただし先頭に「This flake file is community maintained」とあり、出力は package / devShell / `overlays.default` だけで、NixOS モジュールもバイナリキャッシュも無い | https://github.com/niri-wm/niri/blob/main/flake.nix | 確認済み |
| FUN-1 | niri 上流の Getting Started は、NixOS 向けに `epireyn/niri-flake` を挙げ、「maintained fork of sodiboo/niri-flake」と書いている。sodiboo/niri-flake の最後のコミットは 2026-08-04 (lock 更新の自動 PR)。epireyn 版は 2026-10-23 にも更新があり、独自の cachix `niri-epireyn.cachix.org` (個人管理。README に「you are trusting me」と明記) を持つ。NixOS / Home Manager モジュールを出し、設定をビルド時に検証する | https://github.com/niri-wm/niri/blob/main/docs/wiki/Getting-Started.md 、https://github.com/sodiboo/niri-flake 、https://github.com/epireyn/niri-flake | 確認済み |
| FUN-1 | niri 上流の NixOS に関する注意: 「mesa ドライバが niri とずれる問題がよく起きる。システムの mesa を niri の mesa と合わせること (ずれると TTY から起動したとき黒画面になる)」 | https://github.com/niri-wm/niri/blob/main/docs/wiki/Getting-Started.md | 確認済み |
| FUN-1 | NVIDIA + niri の既知の問題: ドライバのヒープ再利用のクセで、VRAM 使用量が 1GiB 近くまで増える。対策として `/etc/nvidia/nvidia-application-profiles-rc.d/` に `GLVidHeapReuseRatio=0` のプロファイルを置く。niri 単体は 100MiB 程度が正常値。画面共有のちらつきは 25.08 で niri 側が修正済み | https://github.com/niri-wm/niri/blob/main/docs/wiki/Nvidia.md | 確認済み |
| FUN-1 | 上の `/etc` のファイルは NixOS では `environment.etc` で宣言できる [推論。NixOS の通常の /etc 生成の仕組み] | — | [推論] |
| FUN-1 | DMS は nixpkgs に入っている (`dms-shell`、NixOS モジュール `programs.dms-shell`。グリーターは `services/display-managers/dms-greeter.nix`)。nixos-unstable の nixpkgs の版は 1.6.3 で、上流は v2.0.0 (DMS → "Dux Shell" に改名)。nixpkgs 版は cache.nixos.org から取れる | https://github.com/NixOS/nixpkgs/tree/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/by-name/dm/dms-shell 、https://duxlabs.dev/docs/dms/nixos | 確認済み |
| FUN-1 | DMS 上流の flake (`github:duxlabs-dev/dux-shell`。旧 AvengeMedia/DankMaterialShell で、HEAD は同じ commit) は `nixosModules.dank-material-shell`、`homeModules.dank-material-shell`、`homeModules.niri` を出す。`/stable` ブランチと、master (-git) がある。公式ドキュメントは「nixpkgs のモジュールに上流 flake のパッケージを差し込む」方法も載せるが、「依存が自動で有効にならないことがある」と警告している。flake.nix と README にバイナリキャッシュ (nixConfig / cachix) の記述は無い | https://duxlabs.dev/docs/dms/nixos-flake 、https://duxlabs.dev/docs/dms/nixos 、https://github.com/AvengeMedia/DankMaterialShell/blob/master/flake.nix | 確認済み |
| FUN-1 | DMS のドキュメント (nixos-flake のページ) に「niri-flake の niri-stable は 25.08 で、DMS が要るのは 26.05 (nixpkgs にある)」という警告がある | https://duxlabs.dev/docs/dms/nixos-flake | 確認済み |
| FUN-1 | nixpkgs 26.11 のリリースノート (unstable) によると、`programs.dms-shell` の `enableVPN` / `enableDynamicTheming` / `enableAudioWavelength` / `enableCalendarEvents` が削除された。上流 DMS のドキュメントはまだこれらのオプションを載せている (nixpkgs のモジュールと上流のドキュメントがずれている) | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/doc/release-notes/rl-2611.section.md 、https://duxlabs.dev/docs/dms/nixos | 確認済み |
| FUN-1 | fcitx5-hazkey は nixpkgs に**無い** (nixos-unstable の木を grep して該当なし)。上流 (7ka-Hiira/hazkey、旧 fcitx5-hazkey) の配布経路は「AUR と deb パッケージ」、それとソースビルド。上流に flake は無い | https://github.com/7ka-Hiira/fcitx5-hazkey/blob/main/README.md 、https://hazkey.hiira.dev/docs/install | 確認済み |
| FUN-1 | 第三者の flake `aster-void/nix-hazkey` がある (いまのユーザーの nix-config も入力に使っている)。これは上流の**ビルド済み tarball** (GitHub Releases の `fcitx5-hazkey-<ver>-x86_64.tar.gz`) を autoPatchelf で包み直すもので、ソースからはビルドしない。NixOS / Home Manager のモジュール (`services.hazkey.enable`) を出す。版の更新は `update.sh` (nix-update) を手で回す。CI は flake-check だけで、自動更新は無い。コミットの大半は個人 (aster / aster-void) によるもの。最後のコミットは 2026-09-25 | https://github.com/aster-void/nix-hazkey | 確認済み |
| FUN-1 | mozc は nixpkgs にある (`fcitx5-mozc`、`fcitx5-mozc-ut`)。fcitx5 は `i18n.inputMethod` (type = "fcitx5") で有効にする | https://github.com/NixOS/nixpkgs/tree/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/by-name/fc/fcitx5-mozc | 確認済み |
| FUN-1 | ghostty: 上流のドキュメントによると、Linux で Nix を使う方法は2つある。nixpkgs の `ghostty` (Nixpkgs のメンテナチームが管理) と、Ghostty プロジェクト自身が管理する flake (tip 版向け)。上流は「普通の利用者には nixpkgs が最も簡単」としている。nixpkgs 版は cache.nixos.org から取れる | https://github.com/ghostty-org/website/blob/main/docs/install/binary.mdx | 確認済み |
| FUN-1 | zen browser は nixpkgs に**無い** (grep で該当なし)。上流の公式ダウンロードは tarball と Flathub だけで、Nix の記述は無い。第三者の `0xc000022070/zen-browser-flake` は上流のビルド済みバイナリを包み直す。更新は GitHub Actions の毎時 cron で自動化されている (beta は上流の GitHub Releases から取る。twilight は flake 作者のリポジトリの Releases に置き直したものを取る)。Home Manager モジュールもある | https://zen-browser.app/download/ 、https://github.com/0xc000022070/zen-browser-flake (sources.json、.github/workflows/zen-update.yml) | 確認済み |
| FUN-1 | Flathub の zen を NixOS で使う経路 (`services.flatpak.enable`) もあるが、宣言の外の状態になる [推論] | — | [推論] |

### FUN-3 / G-LEG-1: NVIDIA ドライバ、CUDA、推論ランタイム

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| FUN-3 | nixpkgs の NVIDIA ドライバのチャネル定義 (nixos-unstable `02c087f`、`pkgs/os-specific/linux/nvidia-x11/default.nix`): `production` = 595.104.02、`new_feature` = 615.78.08、`beta` = 595.45.04、`vulkan_beta` = 595.44.09、`stable` = `production` (i686 だけ legacy_390)、`latest` = production と new_feature の新しい方 (= 615.78.08)、`bleeding_edge` = latest と beta の新しい方 (= 615.78.08)、`dc` = dc_580 (580.178.04)。方針はコメントで「Policy: use the highest stable version as the default」 | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/os-specific/linux/nvidia-x11/default.nix | 確認済み |
| FUN-3 | NixOS モジュールは `hardware.nvidia.branch` (既定 `"stable"`) で上のチャネルを選ぶ。`hardware.nvidia.open` は、560 以上の版では既定 `null` で、明示しないと assertion で止まる (true/false を選ばせる)。`modesetting.enable` は 535 以上で既定 true。`powerManagement.kernelSuspendNotifier` は open かつ 595 以上で既定 true | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/modules/hardware/video/nvidia.nix | 確認済み |
| FUN-3 | NixOS wiki (NVIDIA): open モジュールが推奨で、今後は proprietary を置き換えていく。ただし Turing 以降が対象 (RTX 3060 Ti は Ampere なので対象内)。open を使っても、ユーザー空間は unfree なので `allowUnfree` が要る。Wayland では KMS (`hardware.nvidia.modesetting.enable`) を強く推奨。555 以上で explicit sync に対応する | https://wiki.nixos.org/wiki/NVIDIA | 確認済み |
| FUN-3 | キャッシュの実測 (nixos-unstable `02c087f`、既定カーネル 6.18.57): `nvidia-open-615.78.08-6.18.57` と `nvidia-open-595.104.02-6.18.57` (open カーネルモジュール) は **cache.nixos.org にある** (200)。ユーザー空間の `nvidia-x11-615.78.08` / `nvidia-x11-595.104.02` は cache.nixos.org、cache.nixos-cuda.org、cache.flox.dev の**どれにも無い** (404)。この部分は手元でビルドする (中身は .run の展開とパッチなので軽い [推論]) | 実測: https://cache.nixos.org/<hash>.narinfo ほか (ストアパスは `nix eval` で算出) | 確認済み |
| FUN-3 / G-LEG-1 | nixpkgs の NVIDIA ドライバの license は `unfreeRedistributable`。open でないモジュールを使うときは `nixpkgs.config.nvidia.acceptLicense = true` が要る (open では要らない: `!acceptLicense && openSha256 == null` のときだけ throw する) | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/os-specific/linux/nvidia-x11/generic.nix | 確認済み |
| FUN-3 | CUDA のキャッシュについて、NixOS wiki (CUDA) の記述: 「NixOS Foundation は CUDA パッケージをビルドしない (したがって cache.nixos.org にも載らない)」。理由は unfree ライセンス。CUDA に依存する PyTorch などの閉包も同じ扱いになる | https://wiki.nixos.org/wiki/CUDA | 確認済み |
| FUN-3 | wiki が挙げる CUDA キャッシュは2つ。(1) **NixOS CUDA cache** `https://cache.nixos-cuda.org` (鍵 `cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=`)。(2) **Flox** `https://cache.flox.dev` (鍵 `flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=`)。Flox は NVIDIA と再配布の契約を結んだ事業者で、自社の nixpkgs フォーク (upstream の nixos-unstable を追う。`unstable` ブランチは毎日更新) で release-cuda を回す。wiki は「Flox はリリースチャネルではビルドしないので、チャネルの commit に固定するとキャッシュに当たりにくい」と書いている | https://wiki.nixos.org/wiki/CUDA | 確認済み |
| FUN-3 | cache.nixos-cuda.org を運営するのは Nixpkgs CUDA team (nixos-cuda.org、Hydra は hydra.nixos-cuda.org)。以前は nix-community の Hydra にあった CUDA ジョブを移したもの (nixpkgs PR #459035「release-cuda: remove references to nix-community」。Discourse の引用で確認しており、PR 本体は未読)。jobset の README によると、追う nixpkgs は **`nixos-unstable-small`** (と nixos-26.05-small)。対象は「cudaSupport で hash が変わる約 2k パッケージ」。さらに「NVIDIA の一部製品は成果物の配布がライセンスで許されていない。このキャッシュは **internal development purposes only** を意図している」と明記している。`nixos-unstable-cuda` チャネルを公開する作業は TODO のまま | https://github.com/nixos-cuda/hydra-jobsets/blob/main/README.md 、https://nixos-cuda.org/ 、https://hydra.nixos-cuda.org/project/nixos-cuda 、https://discourse.nixos.org/t/72198 (一次でない: フォーラム) | 確認済み (PR の中身は未検証) |
| FUN-3 | Flox の告知 (2025-09-10、NixOS Discourse の Announcements): Flox は NixOS Foundation、Steering Committee、CUDA team と組んで NVIDIA と CUDA Toolkit の再配布契約を結び、cache.flox.dev を Nix コミュニティに開放した。NixOS 向けには、パッチ済みの CUDA ユーザー空間パッケージと NVIDIA ディスプレイドライバも配るとしている | https://discourse.nixos.org/t/nix-flox-nvidia-opening-up-cuda-redistribution-on-nix/69189 | 確認済み (公式カテゴリの告知) |
| FUN-3 | キャッシュの実測 (nixos-unstable `02c087f`。CUDA Hydra はこの commit を 2026-10-20 に評価している): `ollama-cuda` (= `cudaSupport=true` の `ollama`、同じストアパス)、`llama-cpp-cuda` (= `cudaSupport=true` の `llama-cpp`)、`cudaPackages.cudatoolkit` (cuda-merged-13.4) は、cache.nixos-cuda.org と cache.flox.dev の**両方にある** (200)。cache.nixos.org には無い (404)。CPU 版の `ollama` は cache.nixos.org にある | 実測 (narinfo HEAD/GET)、https://hydra.nixos-cuda.org/jobset/nixos-cuda/cuda-packages-unstable/evals | 確認済み |
| FUN-3 | nixpkgs の推論ランタイム: `ollama` / `ollama-cuda` / `ollama-vulkan` / `ollama-rocm`、`llama-cpp` / `llama-cpp-cuda` / `llama-cpp-vulkan`。NixOS モジュールは `services.ollama` と `services.llama-cpp`。`release-cuda.nix` と CUDA チャネルのブロッカー一覧に `llama-cpp` と `ollama` が入っている | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/top-level/release-cuda.nix 、https://github.com/nixos-cuda/hydra-jobsets/blob/main/channel-blockers.nix | 確認済み |
| FUN-3 | `nixpkgs.config.cudaSupport = true` を全体にかけると、CUDA が関わる大量のパッケージが作り直される (wiki が「expensive mass rebuilds」と書く)。個別に `ollama-cuda` を使えば全体にはかからない。実測でも、`ollama-cuda` のストアパスは全体に cudaSupport をかけた場合と同じだった | https://wiki.nixos.org/wiki/CUDA 、実測 | 確認済み |

### G-HW-7: Secure Boot

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| G-HW-7 | NixOS wiki (Secure Boot): NixOS で Secure Boot を有効にする方法は今のところ2つ、**Lanzaboote** と **Limine** | https://wiki.nixos.org/wiki/Secure_Boot | 確認済み |
| G-HW-7 | lanzaboote は nix-community のプロジェクト。タグの最新は v1.2.0 (v1.0.0 / v1.1.0 / v1.2.0)。nixpkgs からは外れた (`lanzaboote-tool` は 2025-07-23 に削除され、「nix-community/lanzaboote の Nix 式を使え」と案内している)。wiki には「まだ開発中で、今は nixos-unstable でしか使えない」という警告がある。systemd-boot の置き換えとして動き、UEFI と systemd-boot が前提 | https://github.com/nix-community/lanzaboote 、https://wiki.nixos.org/wiki/Lanzaboote 、https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/top-level/aliases.nix | 確認済み |
| G-HW-7 | lanzaboote の方式: 鍵 (sbctl) を手元に置き、ファームウェアを Setup Mode にして**自分の鍵を db に登録する** (`sbctl enroll-keys --microsoft`)。shim / MOK の方式ではない。ドキュメントは「OptionROM が Microsoft の鍵で署名されたハードがあるので、Microsoft の鍵も入れる」としている。鍵はローカルにしか置けない (wiki) | https://github.com/nix-community/lanzaboote/blob/master/docs/getting-started/enable-secure-boot.md 、https://wiki.nixos.org/wiki/Lanzaboote | 確認済み |
| G-HW-7 | Measured Boot (systemd-pcrlock) を使うと、扱える世代数が 8 から 4 に減る (lanzaboote 1.2.0 の CHANGELOG)。Secure Boot だけなら、この制限は書かれていない | https://github.com/nix-community/lanzaboote/blob/master/CHANGELOG.md | 確認済み |
| G-HW-7 | NVIDIA モジュールとの関係: lanzaboote が署名するのはカーネルと initrd (UKI として)。nixpkgs のカーネル設定は `MODULE_SIG = yes` (kmodigest で決定的に署名) と `SECURITY_LOCKDOWN_LSM = yes` だが、`MODULE_SIG_FORCE` は無く、NixOS のモジュールも lockdown や `module.sig_enforce` を有効にしていない。したがって、署名の無い外部モジュール (nvidia-open) も Secure Boot 下で読み込まれ、MOK の登録は要らない [推論。lanzaboote のドキュメントにはカーネルモジュールに関する記述が無い] | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/os-specific/linux/kernel/common-config.nix | [推論] |
| G-HW-7 | Secure Boot を無効にすれば、通常の systemd-boot で起動する (この構成では制約にならない) [推論] | — | [推論] |

### REL-1 / REL-2: 戻す仕組み

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| REL-1 | NixOS manual (Rolling Back): ブートメニューから、GC されていない過去の構成をどれでも起動できる。新しい構成が起動しないときに役立つ。起動後は `/run/current-system/bin/switch-to-configuration boot` で既定にできる。起動中の系は `nixos-rebuild switch --rollback` で前の世代に戻せる | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/doc/manual/administration/rollback.section.md | 確認済み |
| REL-1 | `nixos-rebuild test` は有効化するがブートメニューに入れない。再起動 (やクラッシュ) で、最後に switch/boot した構成に戻る。`nixos-rebuild boot` は次回起動から有効にする | nixos-rebuild(8): https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd | 確認済み |
| REL-1 | 世代に含まれるもの: /nix/store のシステム閉包 (カーネル、initrd、カーネルモジュール。nvidia-open は `boot.kernelPackages` に結びつくので、カーネルと同じ世代で一緒に戻る) と、そこから生成される /etc。世代ごとのカーネルと initrd は ESP に置かれ、ブートエントリになる。[推論: NixOS の構造による。manual の state の章が「/boot にはカーネル、initrd、どのストアパスを使うかを決めるコマンドライン」と書いている] | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/doc/manual/administration/nixos-state.section.md | 一部 [推論] |
| REL-1 | 世代に含まれないもの: manual は `/var/lib/nixos`、`/var/lib/systemd`、`/var/log/journal`、`/etc/machine-id`、(`users.mutableUsers` のときの) `/etc/passwd` / `shadow` などを「永続させるべき状態」として挙げている。つまりこれらは世代の外にあり、ロールバックしても戻らない。/home も同じ [推論]。サービスのデータの形式移行 (DB など) を戻す仕組みは無い (`system.stateVersion` が存在する理由) [推論] | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/doc/manual/administration/nixos-state.section.md 、同 systemd-state.section.md | 一部 [推論] |
| REL-1 | ブートローダ本体 (systemd-boot) は世代と一緒に戻らない。nixpkgs の systemd-boot-builder は `bootctl` の update を呼び、「同じか新しい版が既にあれば何もしない」。古い世代に戻しても、ブートローダは新しい版のまま残る | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/modules/system/boot/loader/systemd-boot/systemd-boot-builder.py | 確認済み |
| REL-1 | ブートメニューに出る世代の数は `boot.loader.systemd-boot.configurationLimit` で制限できる (既定は null = 無制限) | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix | 確認済み |
| REL-1 | Home Manager にも独自の世代がある。`home-manager switch --rollback` と `home-manager generations` が使える (standalone の場合)。NixOS モジュールとして使う場合の世代の扱いは未検証 | https://github.com/nix-community/home-manager/blob/master/docs/manual/usage/rollbacks.md | 確認済み (モジュール時は未検証) |
| REL-1 | specialisation: 1つの世代の中に別の構成を作れて、起動時に選べる (例: GPU ドライバ違い)。`nixos-rebuild switch --specialisation <name>` で切り替える。ふつうの switch は「すべての specialisation をビルドする」(man) | https://wiki.nixos.org/wiki/Specialisation 、nixos-rebuild(8) | 確認済み |
| REL-2 | 部品1つだけ戻す方法: flake の入力は個別に更新できる (`nix flake update <input>`)。niri-flake / DMS / nix-hazkey / zen の flake を別の入力にしておけば、その入力の lock だけを前の commit に戻せる。nixpkgs の中の部品は、古い nixpkgs を2つ目の入力にして overlay で差し替える [推論: 一般的な Nix の使い方。公式の手順書は未確認] | https://github.com/NixOS/nix/blob/master/src/nix/flake-update.md | 一部 [推論] |

### MNT-2: 宣言を変えたときの適用

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| MNT-2 | `nixos-rebuild` は設定全体を評価し、新しいシステムを /nix/store にビルドし、activation script を走らせて、必要なサービスだけ止める・(再)起動する。再起動は要らない (`switch`)。man には「user services は activation script が検出しないので手で起動する必要がある」とある | nixos-rebuild(8) | 確認済み |
| MNT-2 | 変更が1行でも、毎回システム全体の Nix 式を評価し直す。ビルドは差分 (ストアにあるもの、キャッシュにあるものは作らない)。`--store-path` で評価を飛ばし、ビルド済みの閉包を直接適用することもできる | nixos-rebuild(8) | 確認済み |
| MNT-2 | 評価にかかる時間 (このハードと構成で何秒か) | — | 未検証 (測る必要あり) |
| MNT-2 | niri の NixOS モジュールは `restartIfChanged = false`、DMS のモジュールには `systemd.restartIfChanged` がある。コンポジタが更新されてもセッションは再起動されず、新しい版は再ログイン後に有効になる | nixpkgs niri.nix 、https://duxlabs.dev/docs/dms/nixos | 確認済み |
| MNT-2 | `dry-activate` で、activation が再起動するユニットを事前に表示できる (完全ではない) | nixos-rebuild(8) | 確認済み |

### INT-1 / INT-2: アプリが書き換える設定と宣言

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| INT-1 | NixOS wiki (Impermanence): Home Manager で置いたファイルは「read-only で Nix store に置かれる」 | https://wiki.nixos.org/wiki/Impermanence | 確認済み |
| INT-1 | Home Manager manual: ふつう `home.file.<name>.source` は Nix store を経由する。「live path へのリンクを作るには `config.lib.file.mkOutOfStoreSymlink` を使う。store の外の書き換え可能なファイルに追従させたいときに有用」。実装は `ln -s <toString path>` するだけの derivation。関数のコメントは「設定ファイルからの相対パスの絶対パスへリンクする」 | https://github.com/nix-community/home-manager/blob/master/docs/manual/usage/dotfiles.md 、https://github.com/nix-community/home-manager/blob/master/modules/files.nix | 確認済み |
| INT-1 | flake から相対パスを渡すと、flake のソースはストアにコピーされるので、リンク先がストア内 (read-only) になる。リンク先を書き換え可能にしたければ、絶対パスを文字列で渡す [推論。HM の公式文書には、この落とし穴の記述が無い] | — | [推論] |
| INT-1 | HM は管理しないファイルがある場所にリンクを作ろうとすると、activation を止める (衝突の検出)。`-b backup` / `home-manager.backupFileExtension`、ファイルごとの `force = true` で回避できる。manual は force について「ローカルの変更を黙って消すことがある」と警告している | https://github.com/nix-community/home-manager/blob/master/docs/manual/usage/dotfiles.md | 確認済み |
| INT-1 | DMS の HM モジュールは、`settings` / `clipboardSettings` が空でなければ `~/.config/dms/settings.json` (と clsettings.json) を `xdg.configFile` (ストアへのリンク) で書く。プラグインの設定 (`plugin_settings.json`) も `managePluginSettings` で同様に書く。空なら書かない。宣言すると、DMS の設定画面からは書き込めなくなる [推論。前の行の read-only から] | https://github.com/AvengeMedia/DankMaterialShell/blob/master/distro/nix/home.nix | 確認済み (書き込めないことは [推論]) |
| INT-1 | DMS の HM niri モジュールには「config includes hack」がある (`niri.includes`、既定で有効)。これは `~/.config/niri/config.kdl` を上書きし、niri-flake が生成した設定を `hm.kdl` に移す。DMS が書く `~/.config/niri/dms/*.kdl` (alttab, binds, colors, cursor, layout, outputs, windowrules, wpblur) を include する。include 先のファイルが無いと niri は起動時にエラーを出す | https://duxlabs.dev/docs/dms/nixos-flake | 確認済み |
| INT-1 | DMS の NixOS モジュールはコンポジタ用の設定ファイルを生成しない。`dms setup` で既定の設定を置くよう案内している。PAM について: NixOS の /etc/pam.d はモジュールが生成するので、DMS の自動 PAM 管理はロック画面に効かない | https://duxlabs.dev/docs/dms/nixos | 確認済み |
| INT-2 | niri の設定は live reload される。include したファイルも監視され、変更すると再読み込みされる。したがって、書き換え可能な場所 (store の外) に置いたファイルは即時に反映される。HM でストアに置いたファイルは、変更するたびに再ビルドが要る [推論] | https://github.com/niri-wm/niri/blob/main/docs/wiki/Configuration:-Introduction.md 、https://github.com/niri-wm/niri/blob/main/docs/wiki/Configuration:-Include.md | 確認済み (再ビルドが要ることは [推論]) |
| INT-2 | niri-flake の `programs.niri.settings` は設定を Nix で書き、ビルド時に検証する。これは「ストアに置く」側の方式 | https://github.com/sodiboo/niri-flake (README) | 確認済み |

### INT-3: 宣言されていない状態

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| INT-3 | NixOS 本体と Home Manager に、「宣言されていない状態を一覧するコマンド」は見つからなかった (manual、wiki を確認した範囲) | — | 未検証 (無いことの確認は網羅的ではない) |
| INT-3 | 代わりの方式が impermanence。root (と /home) を tmpfs にするか、起動ごとに消す。残すものは `environment.persistence` に列挙する (nix-community/impermanence のモジュール)。NixOS は /boot と /nix だけで起動できる。manual にも「Necessary system state」の章があり、/nix、/boot、/var/lib/nixos、/var/lib/systemd、machine-id などを永続させるべき状態として挙げている | https://wiki.nixos.org/wiki/Impermanence 、https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/doc/manual/administration/system-state.chapter.md | 確認済み |
| INT-3 | impermanence の wiki ページには「Outdated (例が best practice でなく、flake に触れていない)」の印が付いている。HM 側は「Home Manager Impermanence module が fuse マウントとリンクで書き換え可能に永続化する」 | https://wiki.nixos.org/wiki/Impermanence | 確認済み |
| INT-3 | `system.etc.overlay.enable` (/etc を overlayfs で組む) は「experimental」で、既定は false。`mutable` のオプションがある | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/modules/system/etc/etc.nix | 確認済み |

### FLX-1 / FLX-2: 宣言の形

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| FLX-2 | 宣言は Nix 言語の NixOS モジュール。パッケージは nixpkgs の属性名 (例 `pkgs.ollama-cuda`) で並べ、サービスはモジュールのオプション (`services.ollama.enable` など) で書く。他のディストリのパッケージ名やユニットファイルへの対応表は、手で作ることになる [推論] | https://wiki.nixos.org/wiki/Flakes | 一部 [推論] |
| FLX-1 | Home Manager の設定も Nix 言語。`home.file` のファイル本体 (kdl、json など) は持ち越せるが、`programs.*.settings` のように Nix で書いた設定は、その形式のファイルに戻す作業が要る [推論] | — | [推論] |

### FLX-3 / SAF-1: 無人インストール

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| FLX-3 | nixos-anywhere (nix-community、タグの最新は 1.13.0) は、別のマシンから SSH で対象に NixOS を入れる。対象で kexec によって RAM 上の NixOS を起動し、disko でディスクを消して区画を切り、インストールする。OS の無いマシンでも、標準の NixOS インストーラで起動すれば使える (`VARIANT_ID=installer` を検出すると kexec しない)。対象には 1.5GB 以上の RAM が要る。**操作する側のマシンが別に要る** | https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/no-os.md 、同 docs/requirements.md 、https://wiki.nixos.org/wiki/Nixos-anywhere | 確認済み |
| FLX-3 | disko-install (disko に同梱。タグの最新は v1.13.0) は、`nixos-install` に disko の区画作成を足したもの。NixOS インストーラからローカルで実行できる (別マシン不要)。`--flake <url>#<attr> --disk <name> <device>` で flake から1コマンドで入れる。区画を消さずにマウントだけするモードもある | https://github.com/nix-community/disko/blob/master/docs/disko-install.md | 確認済み |
| FLX-3 | disko と nixos-anywhere は nixpkgs にもある (`pkgs/by-name/di/disko`、`pkgs/by-name/ni/nixos-anywhere`) | nixpkgs のツリー | 確認済み |
| FLX-3 | CUDA の閉包はキャッシュから取れる (上の FUN-3 の実測) ので、インストール時のビルドは NVIDIA のユーザー空間ドライバと第三者 flake の部品 (DMS 上流 flake を使うならそれも) に限られる [推論]。1時間以内に収まるかは未検証 | — | 未検証 |
| SAF-1 | disko の公式例は、ディスクを `device = "/dev/disk/by-id/some-disk-id"` で指定している (HowTo の NixOS モジュールの例、disko-install の例)。wiki の例と quickstart は `/dev/vda` や、`lsblk` で調べた名前を使う。by-id で書くのは利用者の責任 | https://github.com/nix-community/disko/blob/master/docs/HowTo.md 、https://github.com/nix-community/disko/blob/master/docs/quickstart.md 、https://wiki.nixos.org/wiki/Disko | 確認済み |
| SAF-1 | disko-install の `--disk <name> <device>` は、宣言の `device` をコマンド行の値で**上書きする** (例のコメント「When using disko-install, we will overwrite this value from the commandline」)。コマンド行に渡すパスも by-id にしないと、宣言で by-id を使っていても守られない [推論] | https://github.com/nix-community/disko/blob/master/docs/disko-install.md | 確認済み (守られないことは [推論]) |
| SAF-1 | wiki と disko の両方が「disko のコマンドはディスクの全データを消す」と警告している | https://wiki.nixos.org/wiki/Disko | 確認済み |

### SEC-3: 第三者ビルドの経路

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| SEC-3 | この構成で使う、公式 (cache.nixos.org / nixpkgs) 以外の入手元: (1) CUDA キャッシュ: cache.nixos-cuda.org (Nixpkgs CUDA team。README に「internal development purposes only」) か cache.flox.dev (Flox 社)。(2) niri-flake (epireyn 個人の cachix。sodiboo 版は更新が止まっている)。nixpkgs の niri を使えば不要。(3) DMS 上流 flake (上流が管理。キャッシュ無し)。nixpkgs の dms-shell を使えば不要。(4) nix-hazkey (個人。上流のビルド済み tarball を包み直す)。(5) zen-browser-flake (コミュニティ。twilight は flake 作者の Releases に置き直したバイナリ)。(6) lanzaboote (nix-community)。(7) home-manager / disko / nixos-anywhere / impermanence (nix-community) | 各リポジトリ (上の表) | 確認済み |
| SEC-3 | 第三者の flake は lock ファイルで commit とハッシュが固定される。キャッシュは `trusted-public-keys` に鍵を登録したものだけが使われる [Nix の仕組み] | https://wiki.nixos.org/wiki/Binary_Cache | 確認済み |
| SEC-3 | NixOS 公式の Security Announcements カテゴリでは、Nix デーモン自体の権限昇格の advisory が続いている: 2025-06-24 (Nix/Lix/Guix)、2026-04-07 (FOD の出力登録時の symlink)、2026-05-04 (Lix/Nix のローカル権限昇格)、2026-10-13 (Nix と Lix)。2026-10-13 には `makeBinaryWrapper` の PATH の空要素の問題もある。第三者 flake / cachix の汚染事件は、この調査では見つからなかった | https://discourse.nixos.org/c/announcements/security/56 | 確認済み (flake/cachix の事件が無いことは未検証) |

### MNT-1 / MNT-4 / MNT-5: 保守

| 制約 ID | 事実 | 出典 URL | 確認 |
|---|---|---|---|
| MNT-1 | nixos-unstable は、Hydra の `nixos/unstable/tested` ジョブが通り、cache.nixos.org がバイナリを取り込んだあとに進む。`-small` は対象パッケージが少なく、早く進む | https://wiki.nixos.org/wiki/Channel_branches | 確認済み |
| MNT-1 | CUDA キャッシュの Hydra は `nixos-unstable-small` を 1800 秒ごとに見て評価している (直近の評価は 2026-10-17〜23 に 15 回)。nixos-unstable の commit でも当たることを実測で確かめた (02c087f) | https://hydra.nixos-cuda.org/jobset/nixos-cuda/cuda-packages-unstable/evals | 確認済み |
| MNT-4 | NixOS には Arch の「manual intervention」ニュースに当たる仕組みは無い。破壊的変更はリリースノートの "Backward Incompatibilities" に載り、多くはオプション名の変更・削除として評価時の警告やエラーで現れる [後半は推論]。unstable の 26.11 リリースノートには、NixOS 側に 80 項目、nixpkgs 側に 115 項目の Backward Incompatibilities がある (26.05 の分岐以降、2026-10-20 時点) | https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/doc/manual/release-notes/rl-2611.section.md 、同 doc/release-notes/rl-2611.section.md | 確認済み (数は grep で数えた) |
| MNT-5 | 回避策の例: niri の NVIDIA VRAM 対策 (`GLVidHeapReuseRatio`) は、上流が「NVIDIA が組み込みプロファイルに入れる可能性は slim」としている。つまり長く残る回避策になる | https://github.com/niri-wm/niri/blob/main/docs/wiki/Nvidia.md | 確認済み |
| 健全性 | home-manager の最終コミットは 2026-10-23。lanzaboote は 2026-10-17 (v1.2.0 が最新タグ)。disko / nixos-anywhere は v1.13.0 / 1.13.0。nix-hazkey は 2026-09-25 (個人)。sodiboo/niri-flake は 2026-08-04 (止まっている)、epireyn/niri-flake は 2026-10-23。zen-browser-flake は 2026-10-21 | 各リポジトリの git log | 確認済み |

## 未検証のまま残したこと

- このハードと構成で `nixos-rebuild switch` の評価に何秒かかるか (MNT-2)。
- Home Manager を NixOS モジュールとして使うとき、HM の世代がシステムの世代と一緒に戻るのか (REL-1)。
- NixOS の公式インストーラ ISO が Secure Boot 有効のまま起動できるか。
- Secure Boot 下で nvidia-open が署名なしで読み込まれること (カーネル設定からの推論で、実機では確かめていない)。
- Limine を使った Secure Boot の詳細 (wiki で名前を確認しただけ)。
- nixpkgs PR #459035 の本文 (CUDA キャッシュの移転の経緯は、Discourse の引用でだけ確認した)。
- cache.nixos-cuda.org が個人の利用を許すかどうか (README は「internal development purposes only」を意図すると書くが、利用条件の明文は見つからなかった)。2025-12 にフォーラムで「unreachable」の報告がある (一次でない)。可用性の SLA は無い [推論]。
- cache.flox.dev が NVIDIA のユーザー空間ドライバ (`nvidia-x11`) を配っているか。告知には「display drivers も配る」とあるが、今回の commit のパスは 404 だった。
- nix-hazkey 以外の hazkey の Nix パッケージ (nixpkgs への PR、NUR など)。GitHub の検索が使えず、確かめられなかった。
- 第三者 flake や cachix の汚染事件が過去にあったか。
- 無人インストールが1時間以内に終わるか (FLX-3)。
- NixOS で「宣言されていない状態を一覧する」第三者ツールがあるか (INT-3)。
