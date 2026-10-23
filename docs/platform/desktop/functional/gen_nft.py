#!/usr/bin/env python3
"""推論 API の nftables 規則を、宣言 (verify/d-v3/designs/design.json) から作る。

ADR-0003 の決定3: このポートへの通信は受信インターフェース (iifname) で判定し、tailscale0 と lo だけを
受け入れる。D-V3 が検査するのは同じ宣言なので、ここで作る規則と検査の対象が一致する。

使い方:
    python3 -I gen_nft.py <design.json> [--iface-map tailscale0=<実際の名前>]
    標準出力に nft の規則を出す。`nft -f -` に渡す。
    --iface-map は代わりの環境 (veth で tailscale0 を模す) でだけ使う。本番では使わない。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

TABLE = "desktop_inference"


def render(design: dict, iface_map: dict[str, str]) -> str:
    if design["network"] != "host":
        raise SystemExit("network が host でない宣言からは規則を作らない (ADR-0003: PublishPort は input チェーンを素通りする)")
    rule = design["nft_input"]
    if rule is None or rule["match"] != "iifname":
        raise SystemExit("nft_input.match が iifname でない宣言からは規則を作らない (ADR-0003: weak host model)")
    ifaces = ", ".join(f'"{iface_map.get(i, i)}"' for i in rule["accept"])
    port = int(design["port"])
    return f"""# 生成元: {design.get('_comment', '')}
# このファイルは gen_nft.py が作る。手で直さない。
table inet {TABLE} {{
    chain input {{
        type filter hook input priority filter - 10; policy accept;
        tcp dport {port} iifname {{ {ifaces} }} accept
        tcp dport {port} drop
    }}
}}
"""


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    design = json.loads(Path(argv[1]).read_text())
    iface_map: dict[str, str] = {}
    if "--iface-map" in argv:
        for kv in argv[argv.index("--iface-map") + 1].split(","):
            k, v = kv.split("=", 1)
            iface_map[k] = v
    sys.stdout.write(render(design, iface_map))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
