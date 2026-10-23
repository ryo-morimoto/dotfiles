#!/usr/bin/env python3
"""MNT-1 (鮮度) の計測: 上流のリリース日と、各候補で使える版・届いた日を一次情報から取り直す。

使い方:
    python3 -m venv .venv && .venv/bin/pip install brotli==1.1.0
    .venv/bin/python -I freshness.py --out-dir snapshots/

出力:
    snapshots/freshness-<日付>.json   生データ (取得元 URL つき)
    snapshots/freshness-<日付>.md     表

指標 (desktop.md MNT-1、N = 3日):
    current_lag_days  今日の時点で、候補が持つ版より新しい上流リリースのうち、最も古いものからの経過日数。
                      候補が上流の最新に追いついていれば 0。
    arrival_lag_days  候補が持つ版について「候補に届いた日 − 上流のリリース日」。届いた日が取れない候補は null。
    history           届いた日の履歴が取れる候補 (Arch 公式、Fedora bodhi、COPR) だけ、過去 180 日の各版の遅延。

上流のリリース日は git タグの日付 (注釈付きタグは tagger date、軽量タグはコミット日)。
CUDA は NVIDIA の redistrib_<版>.json の release_date。プレリリース (rc / beta) は除く。
NVIDIA ドライバは open-gpu-kernel-modules のタグをすべてリリースとして扱う (production / new feature の区別はしない)。

ネットワーク: archlinux.org、aur.archlinux.org、archive.archlinux.org、channels.nixos.org、
bodhi.fedoraproject.org、copr.fedorainfracloud.org、download.opensuse.org、download.nvidia.com、
download1.rpmfusion.org、developer.download.nvidia.com、github.com (git プロトコルのみ)。
取れなかった値は null と "error" を記録し、推測で埋めない。
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import re
import statistics
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

N_DAYS = 3
HISTORY_DAYS = 180
UA = "desktop-freshness-check/1 (+https://github.com/ryo-morimoto/dotfiles)"
TODAY = dt.datetime.now(dt.timezone.utc).date()

# ---------------------------------------------------------------- 上流

UPSTREAM = {
    "niri": {"git": "https://github.com/niri-wm/niri", "tag": r"^v(\d+\.\d+(?:\.\d+)?)$"},
    "dms": {"git": "https://github.com/AvengeMedia/DankMaterialShell", "tag": r"^v(\d+\.\d+\.\d+)$"},
    "hazkey": {"git": "https://github.com/7ka-Hiira/fcitx5-hazkey", "tag": r"^v?(\d+\.\d+\.\d+)$"},
    "nvidia": {"git": "https://github.com/NVIDIA/open-gpu-kernel-modules", "tag": r"^(\d+\.\d+\.\d+)$"},
    "ollama": {"git": "https://github.com/ollama/ollama", "tag": r"^v(\d+\.\d+\.\d+)$"},
    "llama.cpp": {"git": "https://github.com/ggml-org/llama.cpp", "tag": r"^v(\d+\.\d+\.\d+)$"},
    "cuda": {"redist": "https://developer.download.nvidia.com/compute/cuda/redist/"},
}
COMPONENTS = list(UPSTREAM)


def get(url: str, binary: bool = False):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    return data if binary else data.decode("utf-8", "replace")


def vkey(v: str) -> tuple:
    return tuple(int(x) for x in re.findall(r"\d+", v))


def git_tag_dates(url: str, pattern: str, keep: int = 40) -> list[dict]:
    """新しい順に最大 keep 個のタグについて、版と日付を返す。"""
    rx = re.compile(pattern)
    out = subprocess.run(["git", "ls-remote", "--tags", "--refs", url], check=True,
                         capture_output=True, text=True).stdout
    tags = []
    for line in out.splitlines():
        ref = line.split("\t")[1].removeprefix("refs/tags/")
        m = rx.match(ref)
        if m:
            tags.append((vkey(m.group(1)), m.group(1), ref))
    tags.sort(reverse=True)
    tags = tags[:keep]
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["git", "init", "-q", "--bare", d], check=True)
        refspecs = [f"refs/tags/{t[2]}:refs/tags/{t[2]}" for t in tags]
        subprocess.run(["git", "-C", d, "fetch", "-q", "--depth=1", "--filter=tree:0", "--no-tags", url, *refspecs],
                       check=True, capture_output=True)
        fmt = "%(refname:short)\t%(taggerdate:short)\t%(*committerdate:short)\t%(committerdate:short)"
        rows = subprocess.run(["git", "-C", d, "for-each-ref", f"--format={fmt}", "refs/tags"],
                              check=True, capture_output=True, text=True).stdout
    dates = {}
    for row in rows.splitlines():
        name, tagger, deref, commit = (row.split("\t") + ["", "", ""])[:4]
        dates[name] = tagger or deref or commit
    return [{"version": v, "date": dates.get(ref)} for _, v, ref in tags]


def cuda_releases() -> list[dict]:
    base = UPSTREAM["cuda"]["redist"]
    names = sorted(set(re.findall(r"redistrib_(\d+\.\d+\.\d+)\.json", get(base))), key=vkey, reverse=True)[:12]
    rel = []
    for v in names:
        j = json.loads(get(base + f"redistrib_{v}.json"))
        rel.append({"version": v, "date": j.get("release_date")})
    return rel


def upstream_all() -> dict:
    res = {}
    for c, spec in UPSTREAM.items():
        try:
            rel = cuda_releases() if c == "cuda" else git_tag_dates(spec["git"], spec["tag"])
            res[c] = {"source": spec.get("git") or spec.get("redist"), "releases": rel}
        except Exception as e:  # noqa: BLE001 — 取得失敗は記録して続ける
            res[c] = {"source": spec.get("git") or spec.get("redist"), "releases": [], "error": repr(e)}
    return res


# ---------------------------------------------------------------- 候補ごとの取得

def entry(version=None, arrived=None, source=None, note=None, history=None, error=None):
    return {"version": version, "arrived": arrived, "source": source, "note": note,
            "history": history or [], "error": error}


def arch_archive_history(pkg: str) -> list[dict]:
    """archive.archlinux.org の一覧から、各版が最初に出た日を返す。"""
    url = f"https://archive.archlinux.org/packages/{pkg[0]}/{pkg}/"
    text = get(url)
    first: dict[str, str] = {}
    for m in re.finditer(rf'>{re.escape(pkg)}-(\d[^-]*)-(\d+)-[^<]*\.pkg\.tar\.zst</a>\s+(\d\d-\w\w\w-\d{{4}})', text):
        ver, date = m.group(1), dt.datetime.strptime(m.group(3), "%d-%b-%Y").date().isoformat()
        if ver not in first or date < first[ver]:
            first[ver] = date
    return [{"version": v, "arrived": d} for v, d in first.items()]


def arch() -> dict:
    official = {"niri": "niri", "dms": "dms-shell", "nvidia": "nvidia-open", "cuda": "cuda", "ollama": "ollama-cuda",
                "llama.cpp": "llama-cpp"}
    aur = {"hazkey": "fcitx5-hazkey"}
    res = {}
    for c, pkg in official.items():
        try:
            j = json.loads(get(f"https://archlinux.org/packages/search/json/?name={pkg}"))["results"]
            j = [r for r in j if r["repo"] in ("core", "extra")][0]
            hist = arch_archive_history(pkg)
            arrived = next((h["arrived"] for h in hist if h["version"] == j["pkgver"]), j["last_update"][:10])
            res[c] = entry(j["pkgver"], arrived, f"https://archlinux.org/packages/{j['repo']}/x86_64/{pkg}/",
                           f"{j['repo']}/{pkg}", hist)
        except Exception as e:  # noqa: BLE001
            res[c] = entry(source=pkg, error=repr(e))
    try:
        q = "&".join(f"arg[]={p}" for p in aur.values())
        info = {r["Name"]: r for r in json.loads(get(f"https://aur.archlinux.org/rpc/v5/info?{q}"))["results"]}
        for c, pkg in aur.items():
            r = info.get(pkg)
            if not r:
                res[c] = entry(source=pkg, note="AUR に無い")
                continue
            ver = r["Version"].rsplit("-", 1)[0]
            last = dt.datetime.fromtimestamp(r["LastModified"], dt.timezone.utc).date().isoformat()
            res[c] = entry(ver, last, f"https://aur.archlinux.org/packages/{pkg}",
                           f"AUR/{pkg} (届いた日は LastModified。初出より遅い可能性がある)")
    except Exception as e:  # noqa: BLE001
        for c in aur:
            res[c] = entry(error=repr(e))
    return res


def nixos(venv_brotli=True) -> dict:
    import brotli  # pip install brotli==1.1.0
    rev_url = "https://channels.nixos.org/nixos-unstable/packages.json.br"
    data = json.loads(brotli.decompress(get(rev_url, binary=True)))["packages"]
    attrs = {
        "niri": ["niri"],
        "dms": ["dms-shell"],
        "hazkey": ["fcitx5-hazkey"],
        "nvidia": ["linuxPackages_latest.nvidia_x11_latest_open", "linuxPackages.nvidia_x11_latest_open"],
        "cuda": ["cudaPackages.cudatoolkit"],
        "ollama": ["ollama-cuda", "ollama"],
        "llama.cpp": ["llama-cpp"],
    }
    res = {}
    for c, names in attrs.items():
        hit = next((n for n in names if n in data), None)
        if hit is None:
            res[c] = entry(source=rev_url, note=f"nixos-unstable に {names} が無い")
            continue
        ver = re.sub(r"-[\d.]+$", "", data[hit]["version"]) if c == "nvidia" else data[hit]["version"]
        res[c] = entry(ver, None, rev_url, f"nixos-unstable の {hit}。届いた日はチャネルの記録からは取れない")
    # cudatoolkit の version は major.minor しか持たないので、チャネルの git revision にある
    # NVIDIA の redist マニフェスト (redistrib_<版>.json) から、取り込まれた CUDA の版を決める。
    try:
        rev = get("https://channels.nixos.org/nixos-unstable/git-revision").strip()
        base = f"https://raw.githubusercontent.com/NixOS/nixpkgs/{rev}/pkgs/development/cuda-modules/_cuda/manifests/cuda/"
        for r in cuda_releases():
            try:
                get(base + f"redistrib_{r['version']}.json")
            except Exception:  # noqa: BLE001 — 404 なら次の版
                continue
            res["cuda"] = entry(r["version"], None, base,
                                f"nixos-unstable ({rev[:12]}) の nixpkgs に redistrib_{r['version']}.json がある")
            break
    except Exception as e:  # noqa: BLE001
        res["cuda"]["error"] = repr(e)
    return res


def nixos_channel_lag() -> dict:
    """prometheus.nixos.org の channel_update_time から、nixos-unstable が進んだ間隔を出す。"""
    end = dt.datetime.now(dt.timezone.utc)
    start = end - dt.timedelta(days=182)
    q = 'channel_update_time{channel="nixos-unstable"}'
    url = ("https://prometheus.nixos.org/api/v1/query_range?query=" + urllib.request.quote(q)
           + f"&start={start.timestamp():.0f}&end={end.timestamp():.0f}&step=3600")
    j = json.loads(get(url))
    series = j["data"]["result"]
    if not series:
        return {"source": url, "error": "系列が無い"}
    ts = sorted({float(v) for _, v in series[0]["values"]})
    gaps = [(b - a) / 86400 for a, b in zip(ts, ts[1:])]
    # 各時点での「最後の更新からの経過」= チャネルの古さ。1時間ごとのサンプルで測る
    ages = [(float(t) - float(v)) / 86400 for t, v in series[0]["values"]]
    return {
        "source": url,
        "updates": len(ts),
        "gap_days_median": round(statistics.median(gaps), 2) if gaps else None,
        "gap_days_max": round(max(gaps), 2) if gaps else None,
        "age_days_median": round(statistics.median(ages), 2),
        "age_days_p95": round(sorted(ages)[int(len(ages) * 0.95)], 2),
        "age_days_max": round(max(ages), 2),
        "last_update": dt.datetime.fromtimestamp(ts[-1], dt.timezone.utc).isoformat(),
    }


def bodhi_history(pkg: str, release: str) -> list[dict]:
    url = f"https://bodhi.fedoraproject.org/updates/?packages={pkg}&releases={release}&status=stable&rows_per_page=50"
    hist = []
    for u in json.loads(get(url))["updates"]:
        for b in u["builds"]:
            m = re.match(rf"^{re.escape(pkg)}-(\d[^-]*)-", b["nvr"])
            if m and u.get("date_stable"):
                hist.append({"version": m.group(1), "arrived": u["date_stable"][:10]})
    return hist


def copr_history(owner: str, project: str, pkg: str) -> list[dict]:
    url = (f"https://copr.fedorainfracloud.org/api_3/build/list?ownername={owner}&projectname={project}"
           f"&packagename={pkg}&status=succeeded&limit=100")
    hist = []
    for b in json.loads(get(url))["items"]:
        v = (b.get("source_package") or {}).get("version")
        if v and b.get("ended_on"):
            ver = re.sub(r"^\d+:", "", v).rsplit("-", 1)[0]
            d = dt.datetime.fromtimestamp(b["ended_on"], dt.timezone.utc).date().isoformat()
            hist.append({"version": ver, "arrived": d})
    return hist


def listing_versions(url: str, rx: str) -> list[str]:
    return sorted(set(re.findall(rx, html.unescape(get(url)))), key=vkey)


def fedora(release: str = "F44") -> dict:
    n = release[1:]
    res = {}
    for c, pkg in {"niri": "niri", "ollama": "ollama", "llama.cpp": "llama-cpp"}.items():
        try:
            h = bodhi_history(pkg, release)
            if h:
                last = max(h, key=lambda x: (vkey(x["version"]), x["arrived"]))
                arrived = min(x["arrived"] for x in h if x["version"] == last["version"])
                res[c] = entry(last["version"], arrived, f"https://bodhi.fedoraproject.org/updates/?packages={pkg}",
                               f"Fedora {n} 公式 (bodhi stable)", h)
            else:
                res[c] = entry(source=pkg, note=f"Fedora {n} の stable 更新に無い")
        except Exception as e:  # noqa: BLE001
            res[c] = entry(source=pkg, error=repr(e))
    try:
        h = copr_history("avengemedia", "dms", "dms")
        last = max(h, key=lambda x: vkey(x["version"]))
        arrived = min(x["arrived"] for x in h if x["version"] == last["version"])
        res["dms"] = entry(last["version"], arrived, "https://copr.fedorainfracloud.org/coprs/avengemedia/dms/",
                           "COPR avengemedia/dms (上流が運営)", h)
    except Exception as e:  # noqa: BLE001
        res["dms"] = entry(error=repr(e))
    try:
        url = f"https://download1.rpmfusion.org/nonfree/fedora/updates/{n}/x86_64/a/"
        vers = listing_versions(url, r"akmod-nvidia-(\d+\.\d+\.\d+)-\d+\.fc\d+\.x86_64\.rpm")
        res["nvidia"] = entry(vers[-1] if vers else None, None, url, "RPM Fusion nonfree updates (akmod)")
    except Exception as e:  # noqa: BLE001
        res["nvidia"] = entry(error=repr(e))
    try:
        repos = listing_versions("https://developer.download.nvidia.com/compute/cuda/repos/", r"fedora(\d+)/")
        fr = repos[-1] if repos else None
        url = f"https://developer.download.nvidia.com/compute/cuda/repos/fedora{fr}/x86_64/"
        vers = listing_versions(url, r"cuda-toolkit-(\d+-\d+)-(?:\d+\.\d+\.\d+)")
        full = listing_versions(url, r"cuda-toolkit-\d+-\d+-(\d+\.\d+\.\d+)-\d+\.x86_64\.rpm")
        res["cuda"] = entry(full[-1] if full else None, None, url,
                            f"NVIDIA 公式 CUDA リポジトリの最新は fedora{fr} 向け (Fedora {n} 向けではない場合がある)")
    except Exception as e:  # noqa: BLE001
        res["cuda"] = entry(error=repr(e))
    res["hazkey"] = entry(note="Fedora 公式 / 上流の RPM 配布は確認できず (要: 事実調査の結果と照合)")
    return res


def tumbleweed() -> dict:
    oss = "https://download.opensuse.org/tumbleweed/repo/oss/x86_64/"
    text = html.unescape(get(oss))
    res = {}
    rx = {
        "niri": r"\./niri-(\d+\.\d+(?:\.\d+)?)-[\d.]+\.x86_64\.rpm",
        "ollama": r"\./ollama-(\d+\.\d+\.\d+)-[\d.]+\.x86_64\.rpm",
        "llama.cpp": r"\./llamacpp-(\d+\.\d+\.\d+)-[\d.]+\.x86_64\.rpm",
        "nvidia": r"\./nvidia-open-driver-G0\d-signed-kmp-default-(\d+\.\d+\.\d+)_",
        "dms": r"\./(?:dms-shell|dms|DankMaterialShell)-(\d+\.\d+\.\d+)-[\d.]+\.x86_64\.rpm",
        "hazkey": r"\./fcitx5-hazkey-(\d+\.\d+\.\d+)-[\d.]+\.x86_64\.rpm",
    }
    for c, r in rx.items():
        vers = sorted(set(re.findall(r, text)), key=vkey)
        res[c] = entry(vers[-1] if vers else None, None, oss,
                       "Tumbleweed OSS" if vers else "Tumbleweed OSS に無い")
    try:
        nv = "https://download.nvidia.com/opensuse/tumbleweed/x86_64/"
        vers = listing_versions(nv, r"nvidia-open-driver-G\d\d-signed-kmp-default-(\d+\.\d+\.\d+)")
        if vers and (res["nvidia"]["version"] is None or vkey(vers[-1]) > vkey(res["nvidia"]["version"])):
            res["nvidia"] = entry(vers[-1], None, nv, "NVIDIA の openSUSE 向けリポジトリ")
    except Exception as e:  # noqa: BLE001
        res["nvidia"]["error"] = repr(e)
    res["cuda"] = entry(note="NVIDIA 公式 CUDA リポジトリに Tumbleweed 向けの系統は無い (repos 一覧で確認)。opensuse15 / sles 向けを流用する")
    return res


# ---------------------------------------------------------------- 指標

def lag_metrics(up: list[dict], cand: dict) -> dict:
    rel = [r for r in up if r.get("date")]
    if not rel or not cand.get("version"):
        return {"current_lag_days": None, "arrival_lag_days": None}
    ck = vkey(cand["version"])
    newer = [r for r in rel if vkey(r["version"]) > ck]
    cur = 0 if not newer else (TODAY - dt.date.fromisoformat(min(r["date"] for r in newer))).days
    same = [r for r in rel if vkey(r["version"]) == ck]
    arr = None
    if same and cand.get("arrived"):
        arr = (dt.date.fromisoformat(cand["arrived"]) - dt.date.fromisoformat(same[0]["date"])).days
    hist = []
    cutoff = TODAY - dt.timedelta(days=HISTORY_DAYS)
    by_ver = {r["version"]: r["date"] for r in rel}
    for h in cand.get("history", []):
        # 上流の版表記に合わせる (例: Arch の 26.04 と上流の 26.04)
        d = by_ver.get(h["version"])
        if d and dt.date.fromisoformat(d) >= cutoff:
            hist.append((dt.date.fromisoformat(h["arrived"]) - dt.date.fromisoformat(d)).days)
    out = {"current_lag_days": cur, "arrival_lag_days": arr}
    if hist:
        out["history_lags"] = sorted(hist)
        out["history_over_n"] = sum(1 for x in hist if x > N_DAYS)
    return out


def render_md(snap: dict) -> str:
    cands = list(snap["candidates"])
    lines = [f"# 鮮度の計測 ({snap['date']})", "",
             f"MNT-1: 上流のリリースから {N_DAYS} 日以内。`current_lag` は今日の遅れ (0 = 最新に追いついている)。",
             "`arrival` は持っている版が届くまでにかかった日数。`hist` は過去 180 日の各版の遅れ (取れる候補だけ)。", "",
             "## 上流の最新", "", "| 部品 | 最新 | 日付 | 取得元 |", "|---|---|---|---|"]
    for c in COMPONENTS:
        u = snap["upstream"][c]
        r = u["releases"][0] if u["releases"] else {}
        lines.append(f"| {c} | {r.get('version', '—')} | {r.get('date', '—')} | {u['source']}{' (error)' if u.get('error') else ''} |")
    lines += ["", "## 候補ごとの版と遅れ", "", "| 部品 | " + " | ".join(cands) + " |", "|---|" + "---|" * len(cands)]
    for c in COMPONENTS:
        cells = []
        for k in cands:
            e = snap["candidates"][k].get(c, {})
            m = snap["metrics"][k].get(c, {})
            if not e.get("version"):
                cells.append("無し" if not e.get("error") else "取得失敗")
                continue
            s = f"{e['version']} / lag {m.get('current_lag_days')}"
            if m.get("arrival_lag_days") is not None:
                s += f" / arrival {m['arrival_lag_days']}"
            if m.get("history_lags"):
                hl = m["history_lags"]
                s += f" / hist n={len(hl)} med={statistics.median(hl)} max={max(hl)} >{N_DAYS}d={m['history_over_n']}"
            if (m.get("current_lag_days") or 0) > N_DAYS:
                s = "**" + s + "**"
            cells.append(s)
        lines.append(f"| {c} | " + " | ".join(cells) + " |")
    lines += ["", "太字は今日の時点で N 日を超えている。", "", "## 候補ごとの経路", ""]
    for k in cands:
        lines.append(f"- **{k}**")
        for c in COMPONENTS:
            e = snap["candidates"][k].get(c, {})
            lines.append(f"  - {c}: {e.get('note') or ''} {e.get('source') or ''} {('error: ' + e['error']) if e.get('error') else ''}".rstrip())
    ch = snap.get("nixos_channel", {})
    lines += ["", "## nixos-unstable のチャネル (過去 182 日)", "",
              f"- 更新回数 {ch.get('updates')}、更新間隔の中央値 {ch.get('gap_days_median')} 日、最大 {ch.get('gap_days_max')} 日",
              f"- チャネルの古さ: 中央値 {ch.get('age_days_median')} 日、p95 {ch.get('age_days_p95')} 日、最大 {ch.get('age_days_max')} 日",
              f"- 最終更新 {ch.get('last_update')}。取得元: {ch.get('source')}"]
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="snapshots")
    args = ap.parse_args()
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    snap = {"date": TODAY.isoformat(), "n_days": N_DAYS, "upstream": upstream_all(), "candidates": {}, "metrics": {}}
    for name, fn in [("Arch", arch), ("NixOS unstable", nixos), ("Fedora 44", fedora), ("Tumbleweed", tumbleweed)]:
        try:
            snap["candidates"][name] = fn()
        except Exception as e:  # noqa: BLE001
            snap["candidates"][name] = {c: entry(error=repr(e)) for c in COMPONENTS}
    try:
        snap["nixos_channel"] = nixos_channel_lag()
    except Exception as e:  # noqa: BLE001
        snap["nixos_channel"] = {"error": repr(e)}
    for k, cand in snap["candidates"].items():
        snap["metrics"][k] = {c: lag_metrics(snap["upstream"][c]["releases"], cand.get(c, {})) for c in COMPONENTS}

    (out / f"freshness-{TODAY}.json").write_text(json.dumps(snap, ensure_ascii=False, indent=1))
    (out / f"freshness-{TODAY}.md").write_text(render_md(snap))
    print(render_md(snap))
    return 0


if __name__ == "__main__":
    sys.exit(main())
