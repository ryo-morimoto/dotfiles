#!/usr/bin/env python3
"""D-V2: niri 設定の層 (DMS ベース → default-binds → local → dms/*.kdl) で、DMS の設定画面が書いた値が必ず勝つか。

守る制約: INT-1 (アプリが自分で書き換える設定を書き込め、宣言による管理と衝突しない)。

性質 (名前付き invariant):
    DmsUiWriteAlwaysWins: dms/*.kdl が定めた項目は、ほかの層が同じ項目を定めていても、実際に効く値が dms/*.kdl のものになる。

niri の合成規則 (niri commit e19df12cf81ffe805609fee497da1a097066ad2f、2026-10-21 で確認):
    - include は位置で効く。後に読んだものが前のものを上書きする (docs/wiki/Configuration:-Include.md)。
    - 多くの節は項目ごとに合成する (niri-config/src/lib.rs:198-209 の m_merge!、250 の layout、286 の recent-windows)。
    - binds は同じキーを後のもので置き換える (lib.rs:223-235)。
    - prefer-no-csd などのフラグは後のものが勝つ (lib.rs:241)。
    - window-rule / layer-rule は後ろに足され (lib.rs:218-219)、適用は前から順に行い、後の規則が上書きする
      (src/window/mod.rs:203 の ResolvedWindowRules::compute)。
    - output は後ろに足される (lib.rs:212-215) が、画面の設定を引くときは最初に一致したものを使う
      (niri-config/src/output.rs:150 の Outputs::find、iter().find)。← ここだけ「前のものが勝つ」。
    - 1つのファイルの中で、同じ節を2つに分けて書くとエラーになる (lib.rs:160-180。output などの複数部の節は除く)。

使い方:
    python3 -I niri_layers.py model                 # 設計の規則 R1, R2 のもとで全列挙する
    python3 -I niri_layers.py model --drop R1       # 壊した版: R1 を外す
    python3 -I niri_layers.py model --drop R2       # 壊した版: R2 を外す
    python3 -I niri_layers.py lint <config_dir>     # 実際の KDL ファイルが R1, R2 を満たすか

    exit 0 = 性質が成り立つ (lint は規則を満たす)。exit 1 = 反例あり。

設計の規則:
    R1: output 節は dms/*.kdl にだけ書く (ほかの層に output 節を置かない)。
    R2: config.kdl の中で、dms/*.kdl の include は最後に置く (その後ろに節も include も置かない)。
"""

from __future__ import annotations

import itertools
import re
import sys
from pathlib import Path

LAYERS_SPEC = ["base", "default-binds", "local", "dms"]  # 設計の読み込み順 (付録 A.3)

# 項目の種類 → 実際に効く値を決める規則
LAST_WINS = "last-wins"
FIRST_WINS = "first-wins"
KINDS = {
    # 種類: (効き方, 出典)
    "merged-section-property": (LAST_WINS, "lib.rs:198-209,250,286 (merge_with)"),
    "non-merging-subsection": (LAST_WINS, "docs Include.md 'Non-merging sections' (後のものが丸ごと置き換える)"),
    "bind-key": (LAST_WINS, "lib.rs:223-235 (同じキーを置き換える)"),
    "flag": (LAST_WINS, "lib.rs:241"),
    "window-rule-property": (LAST_WINS, "lib.rs:218 + src/window/mod.rs:203 (順に適用、後が上書き)"),
    "output-by-name": (FIRST_WINS, "lib.rs:212-215 + output.rs:150 (Outputs::find は最初の一致)"),
}

# DMS の設定画面が書く dms/*.kdl の中身 (facts-nixos.md: alttab, binds, colors, cursor, layout,
# outputs, windowrules, wpblur) を項目の種類に当てる
DMS_WRITES = {
    "alttab.kdl": "merged-section-property",      # recent-windows
    "binds.kdl": "bind-key",
    "colors.kdl": "merged-section-property",      # layout の色
    "cursor.kdl": "merged-section-property",
    "layout.kdl": "merged-section-property",
    "outputs.kdl": "output-by-name",
    "windowrules.kdl": "window-rule-property",
    "wpblur.kdl": "merged-section-property",      # blur
}


def effective(kind: str, definers: list[str]) -> str:
    """同じ項目を定めた層 (読み込み順) から、実際に効く層を返す。"""
    rule = KINDS[kind][0]
    return definers[-1] if rule == LAST_WINS else definers[0]


def model(drop: set[str]) -> int:
    """層の順と、各項目をどの層が定めるかの組み合わせを全列挙して、DmsUiWriteAlwaysWins を調べる。"""
    # R2 を外すと、dms の include は config.kdl の中のどの位置にも置ける (位置で効くので順が変わる)
    others = [l for l in LAYERS_SPEC if l != "dms"]
    orders = [LAYERS_SPEC] if "R2" not in drop else [others[:i] + ["dms"] + others[i:] for i in range(len(others) + 1)]
    checked = 0
    violations = []
    for order in orders:
        for kind in KINDS:
            for r in range(1, len(order) + 1):
                for subset in itertools.combinations(order, r):
                    if "dms" not in subset:
                        continue
                    # R1: output 節は dms にだけ書く
                    if kind == "output-by-name" and "R1" not in drop and subset != ("dms",):
                        continue
                    checked += 1
                    winner = effective(kind, list(subset))
                    if winner != "dms":
                        violations.append((order, kind, subset, winner))
    print(f"D-V2 model: 規則 {sorted({'R1', 'R2'} - drop)} のもとで {checked} 通りを調べた")
    if violations:
        print(f"FAIL: DmsUiWriteAlwaysWins が破れる ({len(violations)} 通り)。最初の例:")
        order, kind, subset, winner = violations[0]
        print(f"  読み込み順 {' → '.join(order)}、項目の種類 {kind} ({KINDS[kind][1]})")
        print(f"  同じ項目を定めた層 {list(subset)} → 効くのは {winner}。dms の設定画面の値は効かない")
        return 1
    print("OK: DmsUiWriteAlwaysWins が成り立つ")
    return 0


# ---------------------------------------------------------------- 実際のファイルの検査

def top_level_nodes(text: str) -> list[tuple[str, str | None]]:
    """KDL の最上位のノード名と、最初の文字列引数を順に返す。
    扱うもの: 文字列 ("..." と r#"..."#)、// と /* */ のコメント、/- (次のノードを無効にする)、{ } の入れ子。
    扱わないもの: KDL の型注釈など。niri の設定で使う範囲に限る。"""
    nodes: list[tuple[str, str | None]] = []
    i, n, depth = 0, len(text), 0
    at_node_start, skip_next = True, False
    cur_name: str | None = None
    cur_arg: str | None = None
    skipping = False

    def finish():
        nonlocal cur_name, cur_arg, skipping
        if cur_name is not None and not skipping:
            nodes.append((cur_name, cur_arg))
        cur_name, cur_arg, skipping = None, None, False

    while i < n:
        c = text[i]
        if text.startswith("//", i):
            i = text.find("\n", i)
            i = n if i < 0 else i
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if depth == 0 and text.startswith("/-", i):
            skip_next = True
            i += 2
            continue
        if c == '"':
            j = i + 1
            buf = []
            while j < n and text[j] != '"':
                if text[j] == "\\" and j + 1 < n:
                    j += 1
                buf.append(text[j])
                j += 1
            if depth == 0 and cur_name is not None and cur_arg is None:
                cur_arg = "".join(buf)
            i = j + 1
            continue
        m = re.match(r'r(#+)"', text[i:])
        if m:
            end = '"' + m.group(1)
            j = text.find(end, i + len(m.group(0)))
            if depth == 0 and cur_name is not None and cur_arg is None:
                cur_arg = text[i + len(m.group(0)):j]
            i = n if j < 0 else j + len(end)
            continue
        if c == "{":
            depth += 1
            i += 1
            continue
        if c == "}":
            depth -= 1
            i += 1
            if depth == 0:
                finish()
                at_node_start = True
            continue
        if depth == 0:
            if c in "\n;":
                finish()
                at_node_start = True
                i += 1
                continue
            if c.isspace():
                i += 1
                continue
            m = re.match(r"[A-Za-z0-9_\-+.]+(=[^\s;{}]+)?", text[i:])
            if m:
                if at_node_start:
                    cur_name, cur_arg = m.group(0), None
                    skipping, skip_next = skip_next, False
                    at_node_start = False
                i += len(m.group(0))
                continue
        i += 1
    finish()
    return nodes


def lint(config_dir: Path) -> int:
    main = config_dir / "config.kdl"
    if not main.exists():
        print(f"FAIL: {main} が無い")
        return 1
    problems = []
    nodes = top_level_nodes(main.read_text())
    # R2: dms/ の include より後ろに、何も置かない
    dms_idx = [k for k, (name, arg) in enumerate(nodes) if name == "include" and arg and arg.startswith("dms/")]
    if not dms_idx:
        problems.append("R2: config.kdl に dms/*.kdl の include が無い")
    else:
        after = [(name, arg) for name, arg in nodes[dms_idx[0]:] if not (name == "include" and arg and arg.startswith("dms/"))]
        if after:
            problems.append(f"R2: dms/*.kdl の include の後ろに {after} がある (位置で効くので、dms の値を上書きする)")
    # R1: dms/ 以外の層に output 節を置かない (config.kdl 自身と、dms/ 以外の include 先)
    layer_files = [main] + [config_dir / arg for name, arg in nodes if name == "include" and arg and not arg.startswith("dms/")]
    for f in layer_files:
        if not f.exists():
            problems.append(f"include 先 {f} が無い")
            continue
        outs = [arg for name, arg in top_level_nodes(f.read_text()) if name == "output"]
        if outs:
            problems.append(f"R1: {f.relative_to(config_dir)} に output 節 {outs} がある (dms/outputs.kdl の設定が効かなくなる)")
    if problems:
        print(f"FAIL: {config_dir}")
        for p in problems:
            print(f"  {p}")
        return 1
    print(f"OK: {config_dir} は R1, R2 を満たす (include の順: {[a for n, a in nodes if n == 'include']})")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "model":
        drop = set()
        if "--drop" in argv:
            drop = set(argv[argv.index("--drop") + 1].split(","))
        return model(drop)
    if len(argv) == 3 and argv[1] == "lint":
        return lint(Path(argv[2]))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
