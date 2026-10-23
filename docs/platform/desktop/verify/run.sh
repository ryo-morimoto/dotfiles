#!/usr/bin/env bash
# Desktop の形式検証を1コマンドで再実行する。
#   使い方: docs/platform/desktop/verify/run.sh
#   必要なもの: java (11 以上)、curl、sha256sum。TLA+ tools は版と sha256 を固定して取得する。
#   各 .cfg の2行目 "\* expect: <pass | 破れるべき規則名>" と、TLC の結果を突き合わせる。
#   全部が期待どおりなら exit 0。1つでも違えば exit 1。
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/desktop-verify"
TLA_VERSION="v1.7.4"
TLA_SHA256="936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
jar="$cache/tla2tools-$TLA_VERSION.jar"

mkdir -p "$cache"
if [[ ! -f "$jar" ]]; then
  curl -fsSL -o "$jar.tmp" "https://github.com/tlaplus/tlaplus/releases/download/$TLA_VERSION/tla2tools.jar"
  mv "$jar.tmp" "$jar"
fi
echo "$TLA_SHA256  $jar" | sha256sum -c --quiet - || { echo "FAIL: tla2tools.jar の sha256 が違う"; exit 1; }

rc=0
run_tlc() {  # run_tlc <dir> <spec> <cfg>
  local dir="$1" spec="$2" cfg="$3" expect out result
  expect=$(sed -n '2s/^\\\* expect: //p' "$dir/$cfg")
  out=$(cd "$dir" && java -XX:+UseParallelGC -cp "$jar" tlc2.TLC -workers auto -deadlock \
          -metadir "$(mktemp -d)" -config "$cfg" "$spec" 2>&1 | grep -v JAVA_TOOL_OPTIONS || true)
  if grep -q "No error has been found" <<<"$out"; then
    result=pass
  else
    result=$(grep -oE 'Invariant [A-Za-z]+ is violated' <<<"$out" | head -1 | awk '{print $2}')
    [[ -z "$result" ]] && result="error"
  fi
  if [[ "$result" == "$expect" ]]; then
    printf 'ok    %-45s expect=%-22s got=%s\n' "${dir#"$here"/}/$cfg" "$expect" "$result"
  else
    printf 'FAIL  %-45s expect=%-22s got=%s\n' "${dir#"$here"/}/$cfg" "$expect" "$result"
    [[ "$result" == "error" ]] && grep -E "Error|error" <<<"$out" | head -5
    rc=1
  fi
}

# D-V1: 更新と巻き戻し (TLA+)
for cfg in "$here"/d-v1/model/*.cfg; do
  run_tlc "$here/d-v1/model" Rollback.tla "$(basename "$cfg")"
done

# D-V2〜D-V4: Python の標準ライブラリだけで動く検査。expect は 0 (成り立つ) か 1 (反例あり)
run_py() {  # run_py <expect_exit> <label> <args...>
  local expect="$1" label="$2"; shift 2
  local got=0
  python3 -I "$@" >/tmp/desktop-verify.$$ 2>&1 || got=$?
  if [[ "$got" == "$expect" ]]; then
    printf 'ok    %-45s expect=exit%-18s got=exit%s\n' "$label" "$expect" "$got"
  else
    printf 'FAIL  %-45s expect=exit%-18s got=exit%s\n' "$label" "$expect" "$got"
    sed 's/^/      /' /tmp/desktop-verify.$$
    rc=1
  fi
  rm -f /tmp/desktop-verify.$$
}

# D-V2: niri 設定の層 (全列挙 + 実ファイルの検査)
v2="$here/d-v2/niri_layers.py"
run_py 0 "d-v2 model (R1, R2)"            "$v2" model
run_py 1 "d-v2 model --drop R1 (壊した版)" "$v2" model --drop R1
run_py 1 "d-v2 model --drop R2 (壊した版)" "$v2" model --drop R2
for d in "$here"/d-v2/fixtures/*/; do
  name=$(basename "$d"); expect=1; [[ "$name" == good ]] && expect=0
  run_py "$expect" "d-v2 lint fixtures/$name" "$v2" lint "$d"
done

# D-V3: 推論 API の公開範囲 (全列挙)
for f in "$here"/d-v3/designs/*.json; do
  expect=$(python3 -I -c 'import json,sys; print(0 if json.load(open(sys.argv[1]))["expect"]=="pass" else 1)' "$f")
  run_py "$expect" "d-v3 $(basename "$f")" "$here/d-v3/inference_exposure.py" "$f"
done

# D-V4: ディスクの消去の静的検査
for d in "$here"/d-v4/fixtures/*/; do
  name=$(basename "$d"); expect=1; [[ "$name" == good ]] && expect=0
  run_py "$expect" "d-v4 fixtures/$name" "$here/d-v4/wipe_static_check.py" "$d/install"
done

exit $rc
