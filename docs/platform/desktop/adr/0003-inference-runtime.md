---
id: ADR-0003
status: accepted
satisfies: [FUN-3, COMP-2, SEC-1, REL-3, SAF-2, PERF-1]
partial: [COMP-1, MNT-1, PERF-2, PERF-3]
not_satisfied: []
---

# ADR-0003: 推論は上流の llama.cpp コンテナ。Tailscale の内側だけに出す

日付: 2026-10-24。状態: 承認 (2026-10-24)。

## 文脈

- 推論ランタイムは、鮮度を測った部品の中で遅れが最も大きかった。2026-10-23 時点の遅れは次のとおり。
  - llama.cpp: Arch、CachyOS、NixOS でいずれも8日。Fedora 公式は CUDA なし。
  - ollama: NixOS で8日、Fedora 44 で116日 (しかも CUDA なし)。
- 上流の llama.cpp は CUDA 13 版のサーバーイメージ `ghcr.io/ggml-org/llama.cpp:server-cuda13` を配っている。これを使えば、自前でパッケージングせずに上流のリリースと同じ日に使える。ただし上流の文書には「GPU 版のイメージは CI でビルドするだけで、テストはしていない」とある。
- ollama には認証が無い (docs.ollama.com/faq)。llama-server には `--api-key` / `--api-key-file` がある。
- PERF-1 / COMP-1 のため、推論が使う VRAM の上限を、作業面の常駐分 (≤ 0.5GB) を残す値に抑える必要がある。llama-server の `--fit` / `--fit-target` は、デバイスごとに残す余白 (既定 1024MiB) を指定して、未設定の引数を VRAM に合わせて調整する。

## 決定

1. **ランタイム:** `llama-server` (llama.cpp) を、上流のイメージ `ghcr.io/ggml-org/llama.cpp:server-cuda13` で動かす。タグではなくダイジェストで固定し、更新は宣言の変更として行う。
2. **実行:** podman の Quadlet (systemd のユニット) で動かす。GPU は nvidia-container-toolkit (extra) の CDI で渡す。ホストに要るのは NVIDIA ドライバ (`nvidia-open`、extra) だけで、CUDA の実行時ライブラリはイメージの中にある。
3. **待ち受け:** Tailscale のアドレス (tailscale0) だけで待ち受ける。nftables で、tailscale0 以外からこのポートへの通信を落とす。
4. **認証:** 次の2つを重ねる。
   - Tailscale ACL で、届いてよい相手を自分の端末と Server のノードのタグに限る。
   - `--api-key-file` で鍵を要求する。鍵は ADR-0005 の秘密情報として管理する。
5. **VRAM:**
   - `--fit on --fit-target <作業面の余白>` で上限を決める。余白の初期値は 1024MiB とし、PERF-1 の計測で詰める。
   - `--flash-attn on`、`--cache-type-k q8_0`、`--cache-type-v q8_0` を使う。
   - モデルは推論側の予算 (約 7GB) に収まるものに限る。
6. **電力と温度:** `nvidia-smi -pl` で電力上限を設定する systemd ユニットを、推論の前に動かす (SAF-2)。上限値は段階4で計測して決める。
7. **作業面の VRAM 対策 (どの手段でも共通):** `/etc/nvidia/nvidia-application-profiles-rc.d/` に niri 用の `GLVidHeapReuseRatio=0` を置く。

## 満たす制約

| ID | どう満たすか | 根拠 |
|---|---|---|
| FUN-3 | ドライバ (extra) + nvidia-container-toolkit (extra) + 上流の CUDA 版イメージ | archlinux.org packages API、llama.cpp docs/docker.md |
| COMP-2 | llama-server は OpenAI 互換の `/v1/chat/completions` などを出す | llama.cpp tools/server/README.md |
| SEC-1 | tailscale0 だけで待ち受け、nftables で他を落とし、ACL と API キーを重ねる | llama.cpp server README (`--host`、`--api-key-file`) |
| REL-3 | Server は Desktop の推論をベストエフォートとして扱う (7章の約束)。Desktop が止まっても Server の可用性に影響しない | desktop.md 7章 |
| SAF-2 | 電力上限を推論の前に設定する | — |
| PERF-1 | VRAM 対策のプロファイルを置き、推論側の上限を余白つきで決める。常駐分 ≤ 0.5GB は計測で確かめる | niri docs/wiki/Nvidia.md |

## 満たせない制約と妥協

| ID | 満たせない部分 | 妥協の理由と手当て |
|---|---|---|
| COMP-1 (部分) | 推論側がはみ出さないことは `--fit` で抑える。ただし、アプリ (ブラウザなど) が VRAM を増やしたときに作業面が落ちないことは、ドライバの振る舞いに依存し、保証できない | 機能テストで、推論の負荷をかけた状態で作業面が生きていることを確かめる。落ちた事例が出たら、余白を広げるか推論を止める (O1 > O2) |
| MNT-1 (部分) | 上流の GPU 版イメージはテストされていない。新版を即日入れると壊れる可能性がある | ダイジェストで固定し、上げるのは宣言の変更として行う。壊れたら1つ前のダイジェストに戻す (REL-2)。鮮度は「上流のリリース → イメージが出るまで」で数える |
| PERF-2 (部分) | 推論中に 144Hz を保てるかは計測していない | 機能テストで測る。保てないときは推論の優先度を下げる (O2 は従) |
| PERF-3 (部分) | RAM 16GB で、作業面 + 開発 + 推論が swap を常用しないかは計測していない | 機能テストで測る。違反したら G-MON-1 で RAM 増設を判断する (付録 A.2) |

## トレードオフ

- **得るもの:**
  - 推論ランタイムの鮮度と巻き戻しを、OS の更新から切り離せる。
  - Server 側の手段に依存しない (COMP-2)。
  - 同じイメージをどの OS でも使える (FLX-1/2)。
- **失うもの:**
  - コンテナの層が1つ増える。
  - イメージの入手元 (ghcr.io/ggml-org) が第三者ビルドに加わる (SEC-3 の一覧に載せる)。
  - ollama のモデル管理の手軽さを使わない。
- **ollama を選ばない理由:** ollama には認証が無い。SEC-1 を Tailscale だけに頼ることになり、二重にできない。

## 切り替えトリガー

| 条件 | 切り替え先 |
|---|---|
| 上流の CUDA 版イメージが壊れていた事例が四半期に2回 | Arch の `llama-cpp` + `ggml-cuda` (extra) をホストで動かす |
| Server 側が ollama の API を要求する (7章の約束の変更) | 台帳の「Server への確認事項」に書いて協議する |
| Tailscale の ACL で相手を絞れなくなる | 推論 API を止める (SEC-1 は優先順位1位) |

## 検証

- D-V3: 待ち受けアドレス、nftables、Tailscale ACL の設定から、`InferenceOnlyFromAllowedPeers` を検査する (段階3)。
- 機能テスト `drive/inference-reachability`: 許可した相手からは届き、LAN の別端末と許可していない tailnet の端末からは届かないことを確かめる (段階4)。
- 機能テスト `evidence/vram`: 推論を止めた状態で作業面の常駐プロセスの VRAM を合計し、推論中の描画のフレーム時間を測る (段階4)。
