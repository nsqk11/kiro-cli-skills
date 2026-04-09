#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SI="bash $SCRIPT_DIR/si.sh"
DATA="$SCRIPT_DIR/../.data/si.json"
PASS=0 FAIL=0

assert() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $desc"; ((PASS++))
  else
    echo "  ✗ $desc"; echo "    expected: $expected"; echo "    actual:   $actual"; ((FAIL++))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  ✓ $desc"; ((PASS++))
  else
    echo "  ✗ $desc"; echo "    missing: $needle"; ((FAIL++))
  fi
}

reset() { echo '[]' > "$DATA"; }

echo "=== si add ==="
reset
out=$($SI add -t error -k "test,demo" -s "test summary" -d "test detail")
assert "add returns OK" "OK: added" "${out:0:9}"
assert "json has 1 entry" "1" "$(jq length "$DATA")"
assert "status is open" "open" "$(jq -r '.[0].status' "$DATA")"
assert "type is error" "error" "$(jq -r '.[0].type' "$DATA")"

echo "=== si add dedup ==="
out=$($SI add -t error -k "test" -s "another" 2>&1 || true)
assert_contains "dedup detected" "DUPLICATE" "$out"
assert "still 1 entry" "1" "$(jq length "$DATA")"

echo "=== si search ==="
out=$($SI search -k "test")
assert_contains "search finds entry" "test summary" "$out"
out=$($SI search -k "nonexistent")
assert "search no match" "" "$out"

echo "=== si resolve ==="
id=$(jq -r '.[0].id' "$DATA")
$SI resolve -i "$id" -r "fixed it" >/dev/null
assert "status is done" "done" "$(jq -r '.[0].status' "$DATA")"
assert "resolution set" "fixed it" "$(jq -r '.[0].resolution' "$DATA")"

echo "=== si graduate ==="
$SI graduate -i "$id" -S "Preferences" >/dev/null
assert "status is graduated" "graduated" "$(jq -r '.[0].status' "$DATA")"
assert "section set" "Preferences" "$(jq -r '.[0].section' "$DATA")"
assert "skill defaults none" "none" "$(jq -r '.[0].skill' "$DATA")"

echo "=== si graduate with skill ==="
reset
$SI add -t convention -k "skilltest" -s "skill entry" >/dev/null
id=$(jq -r '.[0].id' "$DATA")
$SI resolve -i "$id" >/dev/null
$SI graduate -i "$id" -S "Tool Usage" -k "ca-wow" >/dev/null
assert "skill set" "ca-wow" "$(jq -r '.[0].skill' "$DATA")"

echo "=== si list filters ==="
reset
$SI add -t error -k "a" -s "entry1" >/dev/null
$SI add -t correction -k "b" -s "entry2" >/dev/null
assert "list all = 2" "2" "$(echo "$($SI list)" | wc -l | tr -d ' ')"
assert "list --type error = 1" "1" "$(echo "$($SI list --type error)" | wc -l | tr -d ' ')"

echo "=== si memory ==="
reset
$SI add -t gotcha -k "mem1" -s "memory test" >/dev/null
id=$(jq -r '.[0].id' "$DATA")
$SI resolve -i "$id" >/dev/null
$SI graduate -i "$id" -S "Prefs" >/dev/null
out=$($SI memory)
assert_contains "memory shows graduated" "[Prefs] memory test" "$out"
$SI add -t convention -k "mem2" -s "skilled entry" >/dev/null
id=$(jq -r '.[-1].id' "$DATA")
$SI resolve -i "$id" >/dev/null
$SI graduate -i "$id" -S "Tool" -k "some-skill" >/dev/null
out=$($SI memory)
lines=$(echo "$out" | grep -c "skilled entry" || true)
assert "memory excludes skilled" "0" "$lines"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
reset
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
