# 推論 API

Desktop の GPU で動く推論 API (OpenAI 互換) に、自分の端末と Server のノードと Desktop 自身からは届き、LAN、インターネット、許可していない tailnet の端末からは届かない。推論を止めた状態で、作業面の常駐分が使う VRAM は 0.5GB 以下である。

## Sub-features

- `reach-allowed-peer`: 許可した tailnet の相手から `/v1/models` が返る。
- `reach-desktop-self`: Desktop 自身から返る。
- `api-openai-compatible`: OpenAI 互換の `/v1/models` が、API キー付きで返る (COMP-2)。
- `api-requires-key`: API キーが無いと受け付けない。
- `deny-lan-to-lan-ip`: LAN の端末から、Desktop の LAN のアドレス宛ては届かない。
- `deny-lan-to-ts-ip`: LAN の端末から、Desktop の Tailscale のアドレス宛てに LAN 経由で送っても届かない。Linux は別の NIC 宛てのアドレスも受け取る (weak host model) ので、ここが破れやすい。
- `deny-other-tailnet`: 許可していない tailnet の端末から届かない。Tailscale の ACL による。
- `vram-resident-le-512mib`: 推論を止めた状態で、作業面の常駐分の VRAM が 0.5GB 以下 (PERF-1)。
- `vram-per-process`: プロセスごとの VRAM の一覧 (PERF-5)。

## How to get to it (user POV)

- Server のエージェントが、tailnet の名前で `http://<desktop の MagicDNS 名>:8080/v1/...` を API キー付きで叩く。
- 自分の端末から、同じ URL を叩く。
- Desktop の上のツールが叩く。

## Driving it with dv

Preconditions:

- 実機: `dv doctor` の `llama` と `tailscale` が pass。API キーは `/etc/llama/api-keys` にある (ADR-0005)。
- 実機: 相手の端末に ssh で入れる。`DV_ALLOWED_PEER` (Server か自分の端末)、`DV_DENIED_PEER` (tailnet の許可していない端末)、`DV_LAN_PEER` (LAN の端末) を設定する。未設定の相手は skip になる。
- 代わりの環境: root で `DV_TARGET=standin` を付けて `dv launch` 済み。

Steps:

- **公開範囲を確かめる (実機)。** `DV_ALLOWED_PEER=server-1 DV_DENIED_PEER=guest-phone DV_LAN_PEER=nas.lan docs/platform/desktop/functional/dv drive inference` を実行する。各相手から `curl` した HTTP のコードが、`<id>.stdout` に残る。届かない確認は、TCP がつながらない (コード 000) ことで判定する。
- **LAN から Tailscale のアドレス宛てを試す (実機、人の操作)。** LAN の端末で、`sudo ip route add <Desktop の Tailscale の IPv4>/32 via <Desktop の LAN の IPv4>` を実行する。そのうえで `curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://<Tailscale の IPv4>:8080/v1/models` を叩き、`000` であることを確かめる。最後に経路を消す (`sudo ip route del ...`)。出力を証拠のフォルダの `deny-lan-to-ts-ip.manual.txt` に置く。
- **公開範囲を確かめる (代わりの環境)。** `sudo DV_TARGET=standin DV_RUN_ID=<ID> docs/platform/desktop/functional/dv drive inference` を実行する。LAN の namespace から、LAN のアドレス宛てと Tailscale のアドレス宛ての両方が届かない。tailnet の namespace と Desktop 自身からは届く。
- **検査が効いていることを確かめる (代わりの環境)。** `DV_STANDIN_NFT=docs/platform/desktop/functional/standin/broken-daddr.nft` を付けて launch から行う。`deny-lan-to-ts-ip` が fail になれば、検査は効いている。
- **VRAM を測る (実機)。** `dv drive inference` の最後で、推論サービスを止めて `vram.sh resident-mib` と `vram.sh per-process` を取り、サービスを戻す。

## Gotchas

- `curl -f` は 401 でも失敗する。そのため、「届かない」の確認に使うと、届いたのに PASS になる。`dv` の `CONNECTS` (HTTP のコードが 000 か) を使う。
- 代わりの環境は代用である。実機との違いは3つある。
  - tailscale0 は TUN ではなく veth である。
  - Tailscale の ACL が無いので、`deny-other-tailnet` は skip になる。
  - llama-server の代わりに `python3 -m http.server` を Tailscale のアドレスで待ち受けさせている。届くかどうかだけを見ていて、API キーと OpenAI 互換は見ていない。
- 実機の `deny-other-tailnet` は、Server 側の ACL (`server-requests/0001-inference-acl.md`) が入っていないと fail になる。そのときは Desktop 側を緩めず、Server への依頼の状態を台帳で確かめる。
- `nvidia-smi -q -d PIDS` の `Used GPU Memory` が `Not available` のプロセスがあると、`vram.sh resident-mib` は `NA` を出して exit 2 になる [ドライバの版による。未検証]。そのときは `vram.sh total-mib` を、推論を止めてアプリを閉じた状態で取り、代わりの値として記録する。
- 推論サービスを止めている間、Server からの推論は失敗する。7章の約束はベストエフォートなので、約束は破らない。ただし長く止めない。
