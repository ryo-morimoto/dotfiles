#!/usr/bin/env bash
# VRAM の計測 (PERF-1 / PERF-5)。nvidia-smi -q -d PIDS の出力を読む。
#   vram.sh resident-mib   作業面の常駐分 (niri、DMS (quickshell)、ghostty、fcitx5、xwayland-satellite) の合計 MiB を出す
#   vram.sh per-process    プロセスごとの VRAM を「pid<TAB>名前<TAB>MiB」で出す (PERF-5)
#   vram.sh total-mib      GPU 全体の使用量 (memory.used) を出す
# 常駐分のプロセス名は RESIDENT で決める。名前が変わったら (DMS の改名など) ここを直す。
set -euo pipefail

RESIDENT='^(niri|qs|quickshell|dms|dux-shell|ghostty|fcitx5|xwayland-satellite|Xwayland)$'

per_process() {
  nvidia-smi -q -d PIDS | awk '
    /Process ID/        { pid=$NF }
    /Name/ && pid!=""   { sub(/^.*: /,""); name=$0; n=split(name,a,"/"); name=a[n] }
    /Used GPU Memory/   { v=$(NF-1); if (v ~ /^[0-9]+$/) print pid "\t" name "\t" v; else print pid "\t" name "\tNA"; pid="" }'
}

case "${1:-}" in
  per-process) per_process ;;
  resident-mib)
    per_process | awk -F'\t' -v re="$RESIDENT" '
      $2 ~ re { if ($3=="NA") na=1; else s+=$3 }
      END { if (na) { print "NA"; exit 2 } print s+0 }' ;;
  total-mib) nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits ;;
  *) sed -n '2,7p' "$0"; exit 2 ;;
esac
