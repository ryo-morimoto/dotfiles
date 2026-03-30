#!/usr/bin/env bash
# Domain Modeling Metrics Measurement Script
# Usage: ./measure_metrics.sh <source-directory> <ts|mbt>
#
# Measures 4 key domain modeling health indicators:
#   1. Placeholder count (TODO/unknown/any types)
#   2. External branch count (domain concepts in if/switch/match instead of union types)
#   3. Signature lie count (string/any return types hiding narrower actual value domains)
#   4. Type-external rule count (constraints in comments not reflected in types)

set -euo pipefail

SRC_DIR="${1:-.}"
LANG="${2:-ts}"

echo "=== Domain Modeling Metrics ==="
echo "Source: $SRC_DIR"
echo "Language: $LANG"
echo "Date: $(date -Iseconds)"
echo ""

# --- 1. Placeholder count ---
echo "--- Placeholder Count ---"
if [[ "$LANG" == "ts" ]]; then
	PLACEHOLDERS=$(rg -c '(: unknown|: any|_placeholder|// TODO|// UNKNOWN|// HYPOTHESIS)' "$SRC_DIR" --glob '*.ts' --glob '*.tsx' --glob '!node_modules/**' 2>/dev/null | awk -F: '{sum+=$NF} END{print sum+0}')
elif [[ "$LANG" == "mbt" ]]; then
	PLACEHOLDERS=$(rg -c '(_placeholder|// TODO|// UNKNOWN|// HYPOTHESIS|Unknown\b)' "$SRC_DIR" --glob '*.mbt' 2>/dev/null | awk -F: '{sum+=$NF} END{print sum+0}')
else
	echo "  Unsupported language: $LANG (supported: ts, mbt)"
	exit 1
fi
echo "  Count: $PLACEHOLDERS"
echo ""

# --- 2. External branch count ---
echo "--- External Branch Count ---"
echo "  (Domain concept branches outside type definitions)"
if [[ "$LANG" == "ts" ]]; then
	EXTERNAL=$(rg -c '(if \(.*\.(status|state|phase|type|kind|mode) [!=]|switch \(.*\.(status|state|phase|type|kind|mode)\))' "$SRC_DIR" --glob '*.ts' --glob '*.tsx' --glob '!node_modules/**' 2>/dev/null | awk -F: '{sum+=$NF} END{print sum+0}')
elif [[ "$LANG" == "mbt" ]]; then
	EXTERNAL=$(rg -c '(if .*\.(status|state|phase|kind|mode) [!=]|match .*\.(status|state|phase|kind|mode))' "$SRC_DIR" --glob '*.mbt' 2>/dev/null | awk -F: '{sum+=$NF} END{print sum+0}')
fi
echo "  Count: $EXTERNAL"
echo ""

# --- 3. Signature lie count ---
echo "--- Signature Lie Count ---"
echo "  (Functions returning string/any/String that likely have narrower actual domains)"
if [[ "$LANG" == "ts" ]]; then
	LIES=$(rg -c '(: string\b.*\{|=> string\b|: any\b.*\{|=> any\b)' "$SRC_DIR" --glob '*.ts' --glob '*.tsx' --glob '!node_modules/**' --glob '!*.test.*' --glob '!*.spec.*' 2>/dev/null | awk -F: '{sum+=$NF} END{print sum+0}')
elif [[ "$LANG" == "mbt" ]]; then
	LIES=$(rg -c '-> String\b' "$SRC_DIR" --glob '*.mbt' 2>/dev/null | awk -F: '{sum+=$NF} END{print sum+0}')
fi
echo "  Count: $LIES"
echo ""

# --- 4. Type-external rule count ---
echo "--- Type-External Rule Count ---"
echo "  (Constraints in comments not reflected in types)"
RULES=$(rg -c '(// .*must |// .*only |// .*should |// .*at least|// .*at most|// .*never |// .*always |// .*でなければ|// .*の場合のみ|// .*必ず|// .*禁止)' "$SRC_DIR" --glob "*.${LANG}" 2>/dev/null | awk -F: '{sum+=$NF} END{print sum+0}')
echo "  Count: $RULES"
echo ""

# --- Summary ---
echo "=== Summary ==="
echo "  Placeholders:      $PLACEHOLDERS"
echo "  External branches: $EXTERNAL"
echo "  Signature lies:    $LIES"
echo "  Type-external rules: $RULES"
echo ""
echo "All metrics should decrease monotonically across iterations."
echo "Record these values and compare with previous iteration."
