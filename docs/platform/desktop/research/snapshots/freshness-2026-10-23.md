# 鮮度の計測 (2026-10-23)

MNT-1: 上流のリリースから 3 日以内。`current_lag` は今日の遅れ (0 = 最新に追いついている)。
`arrival` は持っている版が届くまでにかかった日数。`hist` は過去 180 日の各版の遅れ (取れる候補だけ)。

## 上流の最新

| 部品 | 最新 | 日付 | 取得元 |
|---|---|---|---|
| niri | 26.04 | 2026-04-25 | https://github.com/niri-wm/niri |
| dms | 2.0.0 | 2026-10-20 | https://github.com/AvengeMedia/DankMaterialShell |
| hazkey | 0.2.1 | 2026-02-08 | https://github.com/7ka-Hiira/fcitx5-hazkey |
| nvidia | 615.78.08 | 2026-10-07 | https://github.com/NVIDIA/open-gpu-kernel-modules |
| ollama | 0.40.9 | 2026-10-22 | https://github.com/ollama/ollama |
| llama.cpp | 0.7.0 | 2026-10-15 | https://github.com/ggml-org/llama.cpp |
| cuda | 13.4.3 | 2026-10-13 | https://developer.download.nvidia.com/compute/cuda/redist/ |

## 候補ごとの版と遅れ

| 部品 | Arch | CachyOS | NixOS unstable | Fedora 44 | Tumbleweed |
|---|---|---|---|---|---|
| niri | 26.04 / lag 0 / arrival 0 | 26.04 / lag 0 / arrival 1 | 26.04 / lag 0 | 26.04 / lag 0 / arrival 15 | 26.04 / lag 0 |
| dms | 1.6.3 / lag 3 / arrival 0 / hist n=9 med=0 max=3 >3d=0 | 1.6.3 / lag 3 / arrival 7 | 1.6.3 / lag 3 | 2.0.0 / lag 0 / arrival 0 / hist n=10 med=0.0 max=1 >3d=0 | 無し |
| hazkey | 0.2.1 / lag 0 / arrival 1 | 0.2.1 / lag 0 / arrival 1 | 無し | 無し | 無し |
| nvidia | 615.78.08 / lag 0 / arrival 1 / hist n=6 med=1.0 max=2 >3d=0 | 615.78.08 / lag 0 / arrival 10 | 615.78.08 / lag 0 | 615.78.08 / lag 0 | **595.104.02 / lag 150** |
| ollama | 0.40.8 / lag 1 / arrival 1 / hist n=34 med=1.0 max=5 >3d=1 | 0.40.8 / lag 1 / arrival 1 | **0.40.4 / lag 8** | **0.12.11 / lag 116** | 0.40.6 / lag 3 |
| llama.cpp | **0.6.0 / lag 8 / arrival 1 / hist n=6 med=1.0 max=5 >3d=1** | **0.6.0 / lag 8 / arrival 1** | **0.6.0 / lag 8** | 無し | 0.7.0 / lag 0 |
| cuda | 13.4.3 / lag 0 / arrival 0 / hist n=5 med=1 max=7 >3d=1 | 13.4.3 / lag 0 / arrival 0 / hist n=5 med=1 max=7 >3d=1 | 13.4.3 / lag 0 | 13.4.3 / lag 0 | 無し |

太字は今日の時点で N 日を超えている。

## 候補ごとの経路

- **Arch**
  - niri: extra/niri https://archlinux.org/packages/extra/x86_64/niri/
  - dms: extra/dms-shell https://archlinux.org/packages/extra/x86_64/dms-shell/
  - hazkey: AUR/fcitx5-hazkey (届いた日は LastModified。初出より遅い可能性がある) https://aur.archlinux.org/packages/fcitx5-hazkey
  - nvidia: extra/nvidia-open https://archlinux.org/packages/extra/x86_64/nvidia-open/
  - ollama: extra/ollama-cuda https://archlinux.org/packages/extra/x86_64/ollama-cuda/
  - llama.cpp: extra/llama-cpp https://archlinux.org/packages/extra/x86_64/llama-cpp/
  - cuda: extra/cuda https://archlinux.org/packages/extra/x86_64/cuda/
- **CachyOS**
  - niri: [cachyos-extra-v3]/niri (届いた日は今の pkgrel の BUILDDATE。再ビルドがあると初出より遅く出る) https://mirror.cachyos.org/repo/x86_64_v3/cachyos-extra-v3/cachyos-extra-v3.db
  - dms: [cachyos]/dms-shell (届いた日は今の pkgrel の BUILDDATE。再ビルドがあると初出より遅く出る) https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos.db
  - hazkey: CachyOS のリポジトリに無いので Arch の値: AUR/fcitx5-hazkey (届いた日は LastModified。初出より遅い可能性がある) https://aur.archlinux.org/packages/fcitx5-hazkey
  - nvidia: [cachyos-extra-v3]/nvidia-open (届いた日は今の pkgrel の BUILDDATE。再ビルドがあると初出より遅く出る) https://mirror.cachyos.org/repo/x86_64_v3/cachyos-extra-v3/cachyos-extra-v3.db
  - ollama: [cachyos-extra-v3]/ollama-cuda (届いた日は今の pkgrel の BUILDDATE。再ビルドがあると初出より遅く出る) https://mirror.cachyos.org/repo/x86_64_v3/cachyos-extra-v3/cachyos-extra-v3.db
  - llama.cpp: [cachyos-extra-v3]/llama-cpp (届いた日は今の pkgrel の BUILDDATE。再ビルドがあると初出より遅く出る) https://mirror.cachyos.org/repo/x86_64_v3/cachyos-extra-v3/cachyos-extra-v3.db
  - cuda: CachyOS のリポジトリに無いので Arch の値: extra/cuda https://archlinux.org/packages/extra/x86_64/cuda/
- **NixOS unstable**
  - niri: nixos-unstable の niri。届いた日はチャネルの記録からは取れない https://channels.nixos.org/nixos-unstable/packages.json.br
  - dms: nixos-unstable の dms-shell。届いた日はチャネルの記録からは取れない https://channels.nixos.org/nixos-unstable/packages.json.br
  - hazkey: nixos-unstable に ['fcitx5-hazkey'] が無い https://channels.nixos.org/nixos-unstable/packages.json.br
  - nvidia: nixos-unstable の linuxPackages_latest.nvidia_x11_latest_open。届いた日はチャネルの記録からは取れない https://channels.nixos.org/nixos-unstable/packages.json.br
  - ollama: nixos-unstable の ollama-cuda。届いた日はチャネルの記録からは取れない https://channels.nixos.org/nixos-unstable/packages.json.br
  - llama.cpp: nixos-unstable の llama-cpp。届いた日はチャネルの記録からは取れない https://channels.nixos.org/nixos-unstable/packages.json.br
  - cuda: nixos-unstable (02c087f3fe67) の nixpkgs に redistrib_13.4.3.json がある https://raw.githubusercontent.com/NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe/pkgs/development/cuda-modules/_cuda/manifests/cuda/
- **Fedora 44**
  - niri: Fedora 44 公式 (bodhi stable) https://bodhi.fedoraproject.org/updates/?packages=niri
  - dms: COPR avengemedia/dms (上流が運営) https://copr.fedorainfracloud.org/coprs/avengemedia/dms/
  - hazkey: Fedora 公式 / 上流の RPM 配布は確認できず (要: 事実調査の結果と照合)
  - nvidia: RPM Fusion nonfree updates (akmod) https://download1.rpmfusion.org/nonfree/fedora/updates/44/x86_64/a/
  - ollama: Fedora 44 公式 (bodhi stable) https://bodhi.fedoraproject.org/updates/?packages=ollama
  - llama.cpp: Fedora 44 の stable 更新に無い llama-cpp
  - cuda: NVIDIA 公式 CUDA リポジトリの最新は fedora44 向け (Fedora 44 向けではない場合がある) https://developer.download.nvidia.com/compute/cuda/repos/fedora44/x86_64/
- **Tumbleweed**
  - niri: Tumbleweed OSS https://download.opensuse.org/tumbleweed/repo/oss/x86_64/
  - dms: Tumbleweed OSS に無い https://download.opensuse.org/tumbleweed/repo/oss/x86_64/
  - hazkey: Tumbleweed OSS に無い https://download.opensuse.org/tumbleweed/repo/oss/x86_64/
  - nvidia: Tumbleweed OSS https://download.opensuse.org/tumbleweed/repo/oss/x86_64/
  - ollama: Tumbleweed OSS https://download.opensuse.org/tumbleweed/repo/oss/x86_64/
  - llama.cpp: Tumbleweed OSS https://download.opensuse.org/tumbleweed/repo/oss/x86_64/
  - cuda: NVIDIA 公式 CUDA リポジトリに Tumbleweed 向けの系統は無い (repos 一覧で確認)。opensuse15 / sles 向けを流用する

## nixos-unstable のチャネル (過去 182 日)

- 更新回数 78、更新間隔の中央値 1.85 日、最大 9.62 日
- チャネルの古さ: 中央値 1.29 日、p95 5.4 日、最大 9.6 日
- 最終更新 2026-10-20T19:02:32+00:00。取得元: https://prometheus.nixos.org/api/v1/query_range?query=channel_update_time%7Bchannel%3D%22nixos-unstable%22%7D&start=1777044735&end=1792769535&step=3600
