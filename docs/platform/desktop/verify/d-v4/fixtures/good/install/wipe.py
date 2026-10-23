#!/usr/bin/env python3
"""消去・初期化の唯一の入口 (ADR-0006)。"""
import json
import os
import subprocess
import sys
import tomllib
from pathlib import Path

DISKS = Path(__file__).with_name("disks.toml")


def resolve_declared(role: str) -> str:
    """宣言の by-id を、ちょうど1つのブロックデバイスに解決し、シリアル番号・容量・マウントを確かめる。"""
    spec = tomllib.loads(DISKS.read_text())[role]
    link = Path(spec["by_id"])
    if not link.is_symlink():
        raise SystemExit(f"{link} が無い")
    dev = str(link.resolve())
    info = json.loads(subprocess.run(["lsblk", "-J", "-b", "-d", "-o", "NAME,SERIAL,SIZE,MOUNTPOINTS", dev],
                                     check=True, capture_output=True, text=True).stdout)["blockdevices"]
    if len(info) != 1:
        raise SystemExit(f"{dev} が1台に解決しない")
    d = info[0]
    if d["serial"] != spec["serial"] or int(d["size"]) != spec["size_bytes"]:
        raise SystemExit(f"{dev} のシリアル番号か容量が宣言と違う: {d}")
    if any(d.get("mountpoints") or []):
        raise SystemExit(f"{dev} はマウントされている")
    if os.environ.get("WIPE_CONFIRM") != spec["by_id"]:
        answer = input(f"{spec['by_id']} ({dev}) を消す。by-id をもう一度入力: ")
        if answer != spec["by_id"]:
            raise SystemExit("確認が一致しない")
    return dev


def wipe_declared(role: str) -> None:
    dev = resolve_declared(role)
    subprocess.run(["wipefs", "--all", dev], check=True)
    subprocess.run(["sgdisk", "--zap-all", dev], check=True)
    if role == "system":
        subprocess.run(["archinstall", "--config", "/tmp/archinstall.json", "--silent", "--disk", dev], check=True)


if __name__ == "__main__":
    wipe_declared(sys.argv[1])
