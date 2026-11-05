# 付録 A の本体: 候補の採点 (2026-10-24)

`desktop.md` v3 の制約 ID ごとに、候補を ◎ / ○ / △ / × で採点する。根拠は一次情報に限る。出典は末尾の [S*] と、事実の一覧 (`research/facts-*.md`) にある。確認できなかったことは「未検証」と書く。推論には [推論] と付ける。

- ◎: 仕組みとして満たし、一次情報で確かめた。
- ○: 満たせるが、条件か手当てが要る。
- △: 部分的にしか満たせない。または大きな手間がかかる。
- ×: 満たせない。

鮮度の数値は `research/snapshots/freshness-2026-10-23.md` (UTC の 2026-10-23 に取得) による。版や遅延の数値は、計測の日に取り直す (`research/freshness.py`)。

## 候補

| 記号 | 候補 | 構成 |
|---|---|---|
| A | Fedora bootc | Zirconium-nvidia を `FROM` にした自前イメージを CI で作り、`bootc upgrade` / `rollback` で運用する |
| A' | Fedora bootc (Universal Blue) | ublue の nvidia 版を土台にして niri と DMS を足す (署名済みの NVIDIA モジュール) |
| B | Arch + decman | Arch の公式リポジトリ、decman、btrfs + snapper + Limine + limine-snapper-sync、chezmoi、mise |
| B' | CachyOS + decman | B と同じ宣言。リポジトリとブートの既定は CachyOS のもの |
| C | NixOS 組み直し | nixos-unstable + 上流の flake。CUDA はビルド済みのキャッシュから取る |
| D | openSUSE Tumbleweed | btrfs + snapper (既定)、宣言は metapac、chezmoi。DMS は OBS の home プロジェクトから |

transactional 系 (Aeon / Kalpa / MicroOS) は外した。Aeon と Kalpa は、NVIDIA ドライバを含むホストへの変更をサポートしないと明記している [S40]。

## 採点

### 優先順位 1〜2 位 (SAF、SEC-1、SEC-2、FUN-1、COMP-1)

| ID | A | A' | B | B' | C | D |
|---|---|---|---|---|---|---|
| SAF-1 MUST | ○ kickstart は by-id を使えると明記 [S30]。`bootc install to-disk` に by-id を渡せるかは未検証 | ○ 同左 | △ archinstall は一致しないデバイスを黙って飛ばす [推論、S12]。ラッパーが要る (ADR-0006) | △ 無人インストールの仕組みが未検証 | ○ disko の例は by-id [S23]。disko-install のコマンド行で上書きされる [S23] | ○ Agama は by-id と「見つからなければ止まる」を指定できる。search を省くと名前順で最初のディスク [S41] |
| SEC-1 MUST | ○ 共通部品 (ADR-0003) | ○ 同左 | ○ 同左 | ○ 同左 | ○ 同左 | ○ 同左 |
| SEC-2 MUST | ○ age / sops | ○ 同左 | ○ age (extra) | ○ 同左 | ◎ agenix を今使っている | ○ age / sops |
| FUN-1 MUST | △ hazkey は非公式 COPR だけで、ソースからのビルドは失敗している [S31]。ghostty は COPR か Terra [S32] | △ 同左。ublue は 2026-10-22 にイメージから fcitx5 を外した [S33] | ◎ hazkey 以外は公式。hazkey は上流が勧める AUR、zen は上流が勧める Flathub [S1][S2][S3] | ◎ 同左。zen は CachyOS がビルド済みを配る [S10] | ○ hazkey は個人の flake (上流の tarball を包み直し、手で更新) [S20]。zen は第三者の flake [S21] | △ DMS は OBS の home 2つにだけある [S42]。hazkey は無く、自分でビルドが要る [S43] |
| COMP-1 MUST | ○ 共通部品 (llama-server の `--fit`)。未検証 | ○ 同左 | ○ 同左 | ○ 同左 | ○ 同左 | ○ 同左 |

### 優先順位 3〜5 位 (MNT-1、REL-1、MNT-2、INT-2、PERF)

| ID | A | A' | B | B' | C | D |
|---|---|---|---|---|---|---|
| MNT-1 MUST (N=3日) | △ COPR は上流が運営し即日 (DMS 2.0.0 は遅れ0日)。Fedora 公式の niri は bodhi で15日遅れ。Zirconium は週1回のビルドで、自前の CI を足す。hazkey の経路が無い [S34] | △ 同左 | ○ 過去180日の超過は cuda 1/5回 (最大7日)、ollama-cuda 1/34回 (最大5日)、llama-cpp 1/6回 (最大5日)。今日は llama-cpp が8日遅れ、DMS は改名で3日目 | ○ 版は Arch と同じ日か1日遅れ (実測) | △ チャネルの古さは中央値1.29日、p95 5.39日、最大9.59日。今日は ollama と llama-cpp が8日遅れ、DMS は 1.6.3 [S24] | × NVIDIA は 595 系列だけで、615 系列が無い (遅れ150日)。DMS と hazkey は公式に無い。CUDA は Tumbleweed に非対応 [S44] |
| REL-1 MUST (15分) | ◎ `bootc rollback` と GRUB メニュー。カーネルとモジュールはデプロイごとに戻る。/var は戻らない [S35] | ◎ 同左 | ○ limine-snapper-sync がブートメニューからの起動と、カーネル込みの復元を提供する。ただし AUR で、ESP が上限に近づくと警告なしにエントリを消す [S4][S5] | ○ 同左を既定で構成する [S11] | ◎ ブートメニューで世代を選べる。カーネルとモジュールも戻る [S25] | ◎ ブートメニューのスナップショットから起動して `snapper rollback`。rpm の DB もルートの中 [S45] |
| MNT-2 MUST (分単位) | × イメージのビルド → 再起動 [S36] | × 同左。rpm-ostree の追加だけは即時に反映できる | ◎ decman が差分だけを適用する。再起動は要らない [S6] | ◎ 同左 | △ 毎回全体を評価し直す。ビルドは差分だけ。評価の時間は未計測 [S26] | ○ zypper + metapac の sync で差分を適用する [S46] |
| INT-2 MUST | ○ /var/home は書き込める | ○ 同左 | ◎ chezmoi はコピーで置く。niri は即時に読み直す | ◎ 同左 | ○ HM でストアに置いたファイルは、変えるたびに再ビルドが要る [推論、S27]。chezmoi なら ◎ | ○ |
| PERF-1 MUST | ○ VRAM 対策のプロファイルを自分で足す (Zirconium には無い) [S37] | ○ 同左 | ○ 共通部品。未計測 | ○ 同左 | ○ 同左 | ○ 同左 |
| PERF-2〜5 | 手段で差が出る根拠は見つからなかった。計測で扱う (段階4) | | | | | |

### そのほかの MUST

| ID | A | A' | B | B' | C | D |
|---|---|---|---|---|---|---|
| FUN-2 | ○ mise は `$HOME` に入る | ○ | ◎ mise と chezmoi は extra | ◎ | ○ mise が取ってくるバイナリには nix-ld が要る [推論] | ○ mise は公式に無く、上流のインストーラで入れる [S47] |
| FUN-3 | ○ negativo17 のドライバと container-toolkit がイメージに入る。Fedora 公式の llama.cpp / ollama は CUDA 無し [S38] | ○ | ◎ nvidia-open、cuda、ollama-cuda、ggml-cuda、nvidia-container-toolkit は extra [S7] | ◎ | ○ CUDA のキャッシュは「internal development purposes only」を意図したものか、Flox のもの。nvidia-x11 は手元でビルドする [S28] | △ CUDA のリポジトリは Tumbleweed 非対応。kmp とユーザー空間の版がずれる [S44] |
| COMP-2 | ◎ 共通部品 (OpenAI 互換) | ◎ | ◎ | ◎ | ◎ | ◎ |
| INT-1 | ○ Zirconium 自身の chezmoi のタイマーが dotfiles を当てる。止める必要がある [S39] | ○ | ◎ `$HOME` は chezmoi、decman は `$HOME` に触れない | ◎ | △ HM のファイルはストアの中で読み取り専用。DMS の HM モジュールは settings.json をストアへのリンクで置く [S27] | ○ |
| REL-3 | ◎ 7章の約束 (ベストエフォート) | ◎ | ◎ | ◎ | ◎ | ◎ |
| REL-4 | ○ 共通方針 (ADR-0004) | ○ | ○ | ○ | ○ | ○ |
| MNT-3 | ○ Containerfile と chezmoi は git。イメージはそこから作る | ○ | ◎ decman と chezmoi を同じリポジトリに置く | ◎ | ◎ flake | ○ metapac の TOML と chezmoi |
| FLX-1 | ◎ chezmoi + mise | ◎ | ◎ | ◎ | ○ HM で書いた設定は Nix の式なので、そのままは持ち越せない | ◎ |

### SHOULD / MAY

| ID | A | A' | B | B' | C | D |
|---|---|---|---|---|---|---|
| REL-2 | △ 戻す単位はイメージ全体 [S35] | △ | ○ pacman のキャッシュか Arch Linux Archive。部分更新は非サポート [S8] | ○ | ○ flake の入力ごとに固定できる [推論] | ○ history リポジトリに約1か月分が残る [S45] |
| REL-5 | ○ 共通 (`nofail`) | ○ | ○ | ○ | ○ | ○ |
| SEC-3 | △ COPR 3つ、Terra、negativo17、koji の URL 直指定、イメージ自体 [S39] | △ ublue のイメージと鍵。Fedora は公式に支持していない [S33] | △ AUR では 2026-06 から悪意あるパッケージの流入が続く。許可リスト3件 (上流の作者が保守) で抑える [S9] | △ AUR は減るが、全パッケージに CachyOS のビルド基盤と鍵が加わる [S10] | ○ ほぼ nixpkgs。hazkey と zen は個人・第三者の flake [S29] | △ OBS の home は「使うな」と wiki にある [S48] |
| SEC-4 | 手段に依らない (エージェントの sandbox 設定) | | | | | |
| COMP-3 | 手段に依らない (Tailscale の MagicDNS) | | | | | |
| INT-3 | ○ `ostree admin config-diff` (/etc だけ) [S36] | ○ | ○ `decman --dry-run` と pacman の一覧 [S6] | ○ | △ 一覧するコマンドが無い。impermanence は大きな作り替え [S27] | ○ `metapac unmanaged` [S46] |
| MNT-4 (週15分) | △ CI、署名の鍵、イメージの保守 | △ | △ ニュースを読むことと AUR の差分を読むこと。手動介入の告知は直近12か月で7件 [S9] | △ | ○ 慣れている。破壊的変更は評価時のエラーとして出る [推論] | △ dup に加えて、OBS home と NVIDIA の版ずれを見る |
| MNT-5 | △ Zirconium には一時的な版の固定がある [S39] | 未検証 | 未検証 | 未検証 | ○ nixpkgs-pending の検査が dotfiles にある | 未検証 |
| FLX-2 | ○ Containerfile の dnf の列挙 | ○ | ◎ Python の集合 (パッケージ / ファイル / ユニット) | ◎ | △ Nix のモジュールの言語 | ○ metapac の TOML |
| FLX-3 (1時間) | ○ kickstart / ISO。未計測 | ○ | ○ `archinstall --config`。未計測 | △ 無人インストールの仕組みが未検証 | ○ disko-install。未計測 | ○ Agama。未計測 |
| FLX-4 | 未検証 | | | | | |
| SAF-2 | 手段に依らない (`nvidia-smi -pl`) | | | | | |

### 参考 (G: 所与への適合)

| ID | A | A' | B | B' | C | D |
|---|---|---|---|---|---|---|
| G-HW-7 Secure Boot | × NVIDIA 版は Secure Boot を使えないと README にある [S37] | ○ ublue の鍵を MOK に登録する [S33] | ○ sbctl。ISO は Secure Boot で起動できない [S13] | ○ 同左 | ○ lanzaboote [S22] | ◎ OSS の open kmp は openSUSE Secure Boot CA の署名付き (MOK が要らないかは [推論]) [S49] |
| G-PPL-2 スキル | △ | △ | ○ | ○ | ◎ | △ |

## まとめ

| 候補 | 優先順位 3〜5 位で効いたこと | 判定 |
|---|---|---|
| **B** | MNT-1 ○、MNT-2 ◎、FUN-1 ◎、INT-1/2 ◎。REL-1 は ○ で、D-V1 と訓練で確かめる。SEC-3 は △ で、許可リストで抑える | **選ぶ** (ADR-0001〜0007) |
| B' | B とほぼ同じ。鮮度は上がらない。全パッケージに第三者の基盤が加わり、無人インストールが未検証 | 選ばない (ADR-0001 に理由) |
| C | REL-1 ◎ だが、優先順位が上の MNT-1 が △、MNT-2 が △、INT-1 が △ | 切り替え先 (REL-1 違反が四半期に2回) |
| A / A' | REL-1 ◎ だが、MNT-2 が × (MUST を満たせない)。hazkey の経路が無い | 選ばない |
| D | MNT-1 が × (NVIDIA の新しい系列、DMS、hazkey、CUDA) | 選ばない |

## 出典

| キー | 出典 |
|---|---|
| S1 | https://archlinux.org/packages/search/json/?name=niri ほか (2026-10-23/24 に取得) |
| S2 | https://hazkey.hiira.dev/docs/install/archlinux |
| S3 | https://docs.zen-browser.app/guides/install-linux |
| S4 | https://wiki.archlinux.org/title/Limine 、https://gitlab.com/Zesko/limine-snapper-sync |
| S5 | https://wiki.archlinux.org/title/Snapper |
| S6 | https://github.com/kiviktnm/decman (README、docs/pacman.md、docs/aur.md) |
| S7 | https://archlinux.org/packages/extra/x86_64/llama-cpp/files/json/ 、https://archlinux.org/packages/search/json/?name=ggml-cuda |
| S8 | https://wiki.archlinux.org/title/Downgrading_packages 、https://wiki.archlinux.org/title/System_maintenance |
| S9 | https://archlinux.org/news/active-aur-malicious-packages-incident/ 、https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/ 、https://archlinux.org/news/ |
| S10 | https://wiki.cachyos.org/features/optimized_repos/ 、https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos.db |
| S11 | https://wiki.cachyos.org/installation/boot_managers/ 、https://wiki.cachyos.org/configuration/btrfs_snapshots/ |
| S12 | https://github.com/archlinux/archinstall (lib/models/device.py、docs/installing/guided.rst) |
| S13 | https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot |
| S20 | https://github.com/aster-void/nix-hazkey |
| S21 | https://github.com/0xc000022070/zen-browser-flake |
| S22 | https://github.com/nix-community/lanzaboote 、https://wiki.nixos.org/wiki/Lanzaboote |
| S23 | https://github.com/nix-community/disko (docs/HowTo.md、docs/disko-install.md) |
| S24 | https://prometheus.nixos.org/api/v1/query_range?query=channel_update_time 、https://channels.nixos.org/nixos-unstable/packages.json.br |
| S25 | nixpkgs `nixos/doc/manual/administration/rollback.section.md` (commit 02c087f) |
| S26 | nixos-rebuild(8) (nixpkgs commit 02c087f) |
| S27 | https://github.com/nix-community/home-manager (docs/manual/usage/dotfiles.md)、https://wiki.nixos.org/wiki/Impermanence 、DMS `distro/nix/home.nix` |
| S28 | https://wiki.nixos.org/wiki/CUDA 、https://github.com/nixos-cuda/hydra-jobsets/blob/main/README.md |
| S29 | facts-nixos.md の SEC-3 の行 |
| S30 | https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html |
| S31 | https://copr.fedorainfracloud.org/coprs/cocoa/hazkey/ |
| S32 | https://ghostty.org/docs/install/binary |
| S33 | https://github.com/ublue-os/main 、https://github.com/ublue-os/bluefin 、https://docs.fedoraproject.org/en-US/atomic-desktops/troubleshooting/ |
| S34 | https://bodhi.fedoraproject.org/updates/?packages=niri 、https://copr.fedorainfracloud.org/coprs/avengemedia/dms/ 、https://github.com/zirconium-dev/zirconium (.github/workflows) |
| S35 | https://github.com/bootc-dev/bootc (docs/src/bootc-filesystem.7.md、man/bootc-rollback.8.md) |
| S36 | https://github.com/bootc-dev/bootc (docs/src/bootc-upgrades.7.md、bootc-local-builds.7.md) |
| S37 | https://github.com/zirconium-dev/zirconium (README、mkosi.profiles/nvidia)、https://github.com/niri-wm/niri/blob/main/docs/wiki/Nvidia.md |
| S38 | https://src.fedoraproject.org/rpms/llama-cpp 、https://src.fedoraproject.org/rpms/ollama |
| S39 | https://github.com/zirconium-dev/zirconium (repos.d、mkosi.conf.d、systemd/user/chezmoi-*) |
| S40 | https://github.com/AeonDesktop/Project/wiki 、https://en.opensuse.org/Portal:Kalpa |
| S41 | https://github.com/agama-project/agama-project.github.io (docs/user/reference/profile/storage.md) |
| S42 | https://download.opensuse.org/repositories/home:/AvengeMedia:/dms/openSUSE_Tumbleweed/ |
| S43 | https://hazkey.hiira.dev/docs/install 、https://download.opensuse.org/tumbleweed/repo/oss/ |
| S44 | https://download.opensuse.org/tumbleweed/repo/oss/ 、https://download.nvidia.com/opensuse/tumbleweed/ 、https://developer.download.nvidia.com/compute/cuda/repos/ |
| S45 | https://doc.opensuse.org/documentation/tumbleweed/updating_upgrading_reverting/ 、https://download.opensuse.org/history/ |
| S46 | https://github.com/ripytide/metapac |
| S47 | facts-opensuse.md の FLX-2 の行 (OSS の primary.xml) |
| S48 | https://en.opensuse.org/Additional_package_repositories |
| S49 | OSS の nvidia-open-driver-G07-signed-kmp-default の rpm (モジュール署名を確認) |
