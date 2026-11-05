#!/usr/bin/env python3
"""D-V4: ディスクの消去が、宣言した by-id のディスクにだけ向かうか (静的検査)。

守る制約: SAF-1 (不可逆な操作は対象を一意の ID で指定し、別のディスクを誤って消さない)。

性質 (名前付き invariant):
    WipeTargetsOnlyDeclaredIds: install/ の下で、消去・初期化のコマンドを呼ぶ箇所は
    wipe.py の関数 wipe_declared の中だけにある。そこに渡すデバイスは、同じ関数の中で
    resolve_declared(...) が返した値だけである。

検査の規則 (ADR-0006):
    W1: 消去・初期化のコマンド (DESTRUCTIVE) を、wipe_declared の外で呼ばない (Python も shell も)。
    W2: wipe_declared の中の消去コマンドに渡すデバイスは、resolve_declared(...) を代入した変数だけ。
        "/dev/..." の文字列リテラルを渡さない。
    W3: subprocess に shell=True を使わない。os.system / os.popen を使わない (引数を静的に追えないため)。
    W4: wipe_declared の中で、resolve_declared を呼ぶ前に消去コマンドを呼ばない。

検査しないこと: resolve_declared の中身 (by-id の解決、シリアル番号と容量の照合、マウントの確認) は
実行時の振る舞いなので、機能テスト `drive/install-from-zero` (VM と loop デバイスでの代用) で確かめる。

使い方:
    python3 -I wipe_static_check.py <install_dir>     exit 0 = 成り立つ、exit 1 = 反例あり
"""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

DESTRUCTIVE = {
    "wipefs", "sgdisk", "sfdisk", "parted", "blkdiscard", "dd", "cryptsetup", "nvme", "hdparm",
    "archinstall", "mkswap", "btrfs",  # btrfs は mkfs.btrfs と同じ扱いにしない。下の MKFS で別に見る
}
MKFS = re.compile(r"^mkfs(\.\w+)?$")
SAFE_SUBCOMMANDS = {
    # 消去でないサブコマンド (読むだけ)。これ以外は消去とみなす (fail-closed)
    "btrfs": {"subvolume list", "filesystem show", "device stats"},
    "nvme": {"list", "id-ctrl", "smart-log"},
    "cryptsetup": {"status", "isLuks"},
}
SUBPROCESS_FUNCS = {"run", "call", "check_call", "check_output", "Popen"}


def is_destructive(argv: list[str | None]) -> bool:
    if not argv or argv[0] is None:
        return True  # コマンド名が静的に分からない呼び出しは消去とみなす (fail-closed)
    cmd = Path(argv[0]).name
    if MKFS.match(cmd):
        return True
    if cmd not in DESTRUCTIVE:
        return False
    sub = " ".join(a for a in argv[1:3] if a)
    return not any(sub.startswith(s) for s in SAFE_SUBCOMMANDS.get(cmd, set()))


def literal_argv(node: ast.AST) -> list[str | None] | None:
    """subprocess の第1引数がリストかタプルなら、要素ごとに文字列リテラルを返す (リテラルでなければ None)。"""
    if isinstance(node, (ast.List, ast.Tuple)):
        return [e.value if isinstance(e, ast.Constant) and isinstance(e.value, str) else None for e in node.elts]
    return None


class Checker(ast.NodeVisitor):
    def __init__(self, path: Path):
        self.path = path
        self.func_stack: list[str] = []
        self.resolved_vars: list[set[str]] = []
        self.problems: list[str] = []

    def where(self, node: ast.AST) -> str:
        return f"{self.path}:{node.lineno}"

    def visit_FunctionDef(self, node: ast.FunctionDef):
        self.func_stack.append(node.name)
        self.resolved_vars.append(set())
        self.generic_visit(node)
        self.func_stack.pop()
        self.resolved_vars.pop()

    visit_AsyncFunctionDef = visit_FunctionDef

    def visit_Assign(self, node: ast.Assign):
        # dev = resolve_declared(...) を記録する (W2, W4)
        if (isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name)
                and node.value.func.id == "resolve_declared" and self.resolved_vars):
            for t in node.targets:
                if isinstance(t, ast.Name):
                    self.resolved_vars[-1].add(t.id)
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call):
        f = node.func
        # W3: os.system / os.popen
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == "os" and f.attr in {"system", "popen"}:
            self.problems.append(f"W3 {self.where(node)}: os.{f.attr} は引数を静的に追えないので使わない")
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == "subprocess" and f.attr in SUBPROCESS_FUNCS:
            for kw in node.keywords:
                if kw.arg == "shell" and not (isinstance(kw.value, ast.Constant) and kw.value.value is False):
                    self.problems.append(f"W3 {self.where(node)}: shell=True を使わない")
            if node.args:
                self.check_command(node, node.args[0])
        self.generic_visit(node)

    def check_command(self, call: ast.Call, arg0: ast.AST):
        argv = literal_argv(arg0)
        if argv is None:
            self.problems.append(f"W1 {self.where(call)}: コマンドがリストのリテラルでなく、静的に追えない")
            return
        if not is_destructive(argv):
            return
        cmd = argv[0]
        inside = "wipe_declared" in self.func_stack
        if not inside:
            self.problems.append(f"W1 {self.where(call)}: 消去・初期化のコマンド {cmd} を wipe_declared の外で呼んでいる")
            return
        resolved = self.resolved_vars[self.func_stack.index("wipe_declared")] if self.resolved_vars else set()
        if not resolved:
            self.problems.append(f"W4 {self.where(call)}: resolve_declared を呼ぶ前に {cmd} を呼んでいる")
        for e in arg0.elts:  # type: ignore[attr-defined]
            if isinstance(e, ast.Constant) and isinstance(e.value, str) and e.value.startswith("/dev/"):
                self.problems.append(f"W2 {self.where(call)}: {cmd} にデバイスを文字列リテラル {e.value!r} で渡している")
            if isinstance(e, ast.Name) and e.id not in resolved:
                self.problems.append(f"W2 {self.where(call)}: {cmd} に渡す {e.id} は resolve_declared の戻り値ではない")
            if not isinstance(e, (ast.Constant, ast.Name)):
                self.problems.append(f"W2 {self.where(call)}: {cmd} の引数に式 ({ast.unparse(e)}) があり、静的に追えない")


SHELL_WORD = re.compile(r"(?<![\w.-])(" + "|".join(sorted(DESTRUCTIVE)) + r"|mkfs(\.\w+)?)(?![\w.-])")


def check_shell(path: Path) -> list[str]:
    """shell スクリプトでは、消去・初期化のコマンドを一切呼ばない (W1)。"""
    out = []
    for no, line in enumerate(path.read_text().splitlines(), 1):
        code = line.split("#", 1)[0]
        m = SHELL_WORD.search(code)
        if m and m.group(1) not in SAFE_SUBCOMMANDS:
            out.append(f"W1 {path}:{no}: shell スクリプトで {m.group(1)} を呼んでいる (消去は wipe.py の wipe_declared からだけ)")
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    root = Path(argv[1])
    problems: list[str] = []
    py_files = sorted(root.rglob("*.py"))
    sh_files = sorted(p for p in root.rglob("*") if p.suffix == ".sh" or (p.is_file() and p.read_bytes()[:2] == b"#!" and b"sh" in p.read_bytes()[:20] and p.suffix != ".py"))
    if not any(p.name == "wipe.py" for p in py_files):
        problems.append(f"{root}: wipe.py が無い")
    for p in py_files:
        c = Checker(p)
        c.visit(ast.parse(p.read_text(), filename=str(p)))
        problems += c.problems
    for p in sh_files:
        problems += check_shell(p)
    print(f"D-V4 {root}: Python {len(py_files)} 本、shell {len(sh_files)} 本を検査した")
    if problems:
        print("FAIL: WipeTargetsOnlyDeclaredIds が破れる")
        for p in problems:
            print(f"  {p}")
        return 1
    print("OK: WipeTargetsOnlyDeclaredIds が成り立つ")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
