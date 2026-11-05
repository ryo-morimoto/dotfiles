#!/usr/bin/env python3
"""D-V3: 推論 API の公開範囲。許可した相手 (自分の端末、Server のノード、Desktop 自身) からだけ届くか。

守る制約: SEC-1 (推論 API には認証された相手からだけ届く。LAN 全体やインターネットには出さない)。

性質 (名前付き invariant):
    InferenceOnlyFromAllowedPeers: 推論 API のポートへの TCP 接続が受け付けられるのは、送り元が
    {自分の端末 (tailnet)、Server のノード (tailnet)、Desktop 自身} のどれかのときだけ。

入力は宣言 (JSON) で、段階5で nftables の設定と Quadlet のユニットをここから作る。検査するのは宣言で、
生成物と実機は機能テスト `drive/inference-reachability` で突き合わせる。

モデル (送り元の同値類 × 届くインターフェース × 宛先アドレスを全列挙する):
    - tailnet の送り元は tailscale0 に届く。Tailscale の ACL が許した相手だけが届く
      (ACL は Server 側の設定。server-requests/0001-inference-acl.md の前提として扱う)。
    - LAN とインターネットの送り元は LAN の NIC に届く。宛先は Desktop の LAN のアドレスでも、
      Tailscale のアドレスでもよい。Linux は既定で、ほかの NIC に付いたアドレス宛ての通信も受け取る
      (weak host model) [一般的な事実。rp_filter はこれを止めない]。インターネットからはルータの
      ポート転送があった場合を想定し、LAN と同じに扱う (保守的)。
    - Desktop 自身のプロセスは lo から、どのローカルアドレスにも届く。
    - network = host のとき: 通信は nftables の input チェーンを通り、待ち受けアドレスと照合される。
    - network = bridge で port を publish したとき: netavark が PREROUTING で DNAT し
      (netavark commit 8f38dd8 src/firewall/nft.rs:197-213 `fib daddr type local jump NETAVARK-HOSTPORT-DNAT`)、
      FORWARD で受け入れる (nft.rs:276-283 `ct mark & 0x1000 == 0x1000 accept`)。
      このため、ホストの input チェーンの規則は効かない。

使い方:
    python3 -I inference_exposure.py <design.json>     exit 0 = 成り立つ、exit 1 = 反例あり
"""

from __future__ import annotations

import json
import sys
from itertools import product
from pathlib import Path

ALLOWED = {"own-device", "server", "desktop-itself"}

SOURCES = {
    # 送り元: (届くインターフェース, 宛先にできるアドレス)
    "own-device": ("tailscale0", ["ts-ip"]),
    "server": ("tailscale0", ["ts-ip"]),
    "other-tailnet-device": ("tailscale0", ["ts-ip"]),
    "lan-host": ("lan", ["lan-ip", "ts-ip"]),
    "internet-host": ("lan", ["lan-ip", "ts-ip"]),
    "desktop-itself": ("lo", ["loopback", "lan-ip", "ts-ip"]),
}


def acl_passes(design: dict, source: str, iface: str) -> bool:
    """Tailscale の ACL: tailnet の送り元は、ACL が許したものだけが tailscale0 に届く。"""
    if iface != "tailscale0":
        return True
    return source in design["tailscale_acl_allows"]


def nft_input_accepts(design: dict, iface: str, dst: str) -> bool:
    """nftables の input チェーン (推論のポートだけを見る)。"""
    rule = design["nft_input"]
    if rule is None:
        return True
    if rule["match"] == "iifname":
        return iface in rule["accept"]
    if rule["match"] == "daddr":
        return dst in rule["accept"]
    raise ValueError(rule)


def socket_accepts(listen: str, dst: str) -> bool:
    return listen == "any" or listen == dst


def reachable(design: dict, source: str, iface: str, dst: str) -> bool:
    if not acl_passes(design, source, iface):
        return False
    net = design["network"]
    if net == "host":
        return nft_input_accepts(design, iface, dst) and socket_accepts(design["listen"], dst)
    if net == "bridge":
        pub = design["publish_host_ip"]  # "any" か、アドレスの名前
        if pub is None:
            return False
        # DNAT は宛先がローカルのアドレスなら効く (fib daddr type local)。input チェーンは通らない。
        return pub == "any" or pub == dst
    raise ValueError(net)


def check(design: dict) -> list[tuple[str, str, str]]:
    bad = []
    for source, (iface, dsts) in SOURCES.items():
        for dst in dsts:
            if reachable(design, source, iface, dst) and source not in ALLOWED:
                bad.append((source, iface, dst))
    return bad


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    path = Path(argv[1])
    design = json.loads(path.read_text())
    bad = check(design)
    ok_paths = [(s, i, d) for s, (i, ds) in SOURCES.items() for d in ds if reachable(design, s, i, d)]
    allowed_reach = sorted({s for s, _, _ in ok_paths} & ALLOWED)
    print(f"D-V3 {path.name}: {design.get('_comment', '')}")
    if bad:
        print("FAIL: InferenceOnlyFromAllowedPeers が破れる。届いてしまう経路:")
        for s, i, d in bad:
            print(f"  送り元 {s} → {i} → 宛先 {d}:{design['port']}")
        return 1
    # 空虚に成り立っていないか (許可した相手にも届かない設定は SEC-1 を満たすが FUN-3 を壊す)
    missing = sorted({"own-device", "server"} - set(allowed_reach))
    if missing:
        print(f"FAIL: 許可した相手 {missing} にも届かない (推論 API を出せていない。FUN-3 / COMP-2 を壊す)")
        return 1
    print(f"OK: InferenceOnlyFromAllowedPeers が成り立つ。届く相手: {allowed_reach}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
