#!/usr/bin/env bash
# ゼロからの再現 (ADR-0006)。消去は wipe.py にだけ任せる。ここで archinstall や wipefs を直接呼ばない。
set -euo pipefail
python3 -I "$(dirname "$0")/wipe.py" system
wipefs --all /dev/sda
