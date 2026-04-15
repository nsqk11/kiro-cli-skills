#!/bin/bash
# Regression test for memory.py — covers all 7 subcommands
set -uo pipefail
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

DATA="$TEST_DIR/mem.json"
MEM="env MEM_DATA=$DATA python3.12 $(dirname "$0")/../memory.py"
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

# --- add ---
echo "=== memory add ==="
reset
out=$($MEM add -t error -k "test,demo" -s "test summary" -d "test detail")
assert "add returns OK" "OK: added" "${out:0:9}"
assert "json has 1 entry" "1" "$(jq length "$DATA")"
assert "status is open" "open" "$(jq -r '.[0].status' "$DATA")"
assert "type is error" "error" "$(jq -r '.[0].type' "$DATA")"

# --- add dedup ---
echo "=== memory add dedup ==="
out=$($MEM add -t error -k "test" -s "another" 2>&1 || true)
assert_contains "dedup detected" "DUPLICATE" "$out"
assert "still 1 entry" "1" "$(jq length "$DATA")"

# --- add --force ---
echo "=== memory add --force ==="
out=$($MEM add -t error -k "test" -s "forced entry" --force)
assert_contains "force bypasses dedup" "OK: added" "$out"
assert "now 2 entries" "2" "$(jq length "$DATA")"

# --- search (keyword match) ---
echo "=== memory search (keyword) ==="
out=$($MEM search -q "test")
assert_contains "search finds by keyword" "test summary" "$out"

# --- search (summary match) ---
echo "=== memory search (summary) ==="
out=$($MEM search -q "forced")
assert_contains "search finds by summary" "forced entry" "$out"

# --- search (no match) ---
out=$($MEM search -q "nonexistent")
assert "search no match" "" "$out"

# --- resolve ---
echo "=== memory resolve ==="
reset
$MEM add -t error -k "r1" -s "resolve test" >/dev/null
id=$(jq -r '.[0].id' "$DATA")
$MEM resolve -i "$id" -r "fixed it" >/dev/null
assert "status is done" "done" "$(jq -r '.[0].status' "$DATA")"
assert "resolution set" "fixed it" "$(jq -r '.[0].resolution' "$DATA")"

# --- resolve (bad ID) ---
echo "=== memory resolve (bad ID) ==="
out=$($MEM resolve -i "BADID" 2>&1 || true)
assert_contains "resolve bad ID errors" "not found" "$out"

# --- graduate (default skill) ---
echo "=== memory graduate ==="
$MEM graduate -i "$id" -S "Preferences" >/dev/null
assert "status is graduated" "graduated" "$(jq -r '.[0].status' "$DATA")"
assert "section set" "Preferences" "$(jq -r '.[0].section' "$DATA")"
assert "skill defaults none" "none" "$(jq -r '.[0].skill' "$DATA")"

# --- graduate (with skill) ---
echo "=== memory graduate (with skill) ==="
reset
$MEM add -t convention -k "skilltest" -s "skill entry" >/dev/null
id=$(jq -r '.[0].id' "$DATA")
$MEM resolve -i "$id" >/dev/null
$MEM graduate -i "$id" -S "Tool Usage" -k "my-skill" >/dev/null
assert "skill set" "my-skill" "$(jq -r '.[0].skill' "$DATA")"

# --- graduate (bad ID) ---
echo "=== memory graduate (bad ID) ==="
out=$($MEM graduate -i "BADID" -S "X" 2>&1 || true)
assert_contains "graduate bad ID errors" "not found" "$out"

# --- list (all) ---
echo "=== memory list ==="
reset
$MEM add -t error -k "a" -s "entry1" >/dev/null
$MEM add -t correction -k "b" -s "entry2" >/dev/null
id=$(jq -r '.[0].id' "$DATA")
$MEM resolve -i "$id" >/dev/null
assert "list all = 2" "2" "$($MEM list | wc -l | tr -d ' ')"

# --- list --type ---
assert "list --type error = 1" "1" "$($MEM list --type error | wc -l | tr -d ' ')"

# --- list --status ---
assert "list --status open = 1" "1" "$($MEM list --status open | wc -l | tr -d ' ')"
assert "list --status done = 1" "1" "$($MEM list --status done | wc -l | tr -d ' ')"

# --- list --skill ---
$MEM graduate -i "$id" -S "sec" -k "sk1" >/dev/null
assert "list --skill sk1 = 1" "1" "$($MEM list --skill sk1 | wc -l | tr -d ' ')"

# --- memory ---
echo "=== memory memory ==="
reset
$MEM add -t gotcha -k "mem1" -s "memory test" >/dev/null
id=$(jq -r '.[0].id' "$DATA")
$MEM resolve -i "$id" >/dev/null
$MEM graduate -i "$id" -S "Prefs" >/dev/null
out=$($MEM memory)
assert_contains "memory shows graduated" "[Prefs] memory test" "$out"

$MEM add -t convention -k "mem2" -s "skilled entry" >/dev/null
id=$(jq -r '.[-1].id' "$DATA")
$MEM resolve -i "$id" >/dev/null
$MEM graduate -i "$id" -S "Tool" -k "some-skill" >/dev/null
out=$($MEM memory)
lines=$(echo "$out" | grep -c "skilled entry" || true)
assert "memory excludes skilled" "0" "$lines"

# --- clean (dry run) ---
echo "=== memory clean ==="
out=$($MEM clean)
assert_contains "clean dry run" "dry run" "$out"
assert "entries unchanged after dry run" "2" "$(jq length "$DATA")"

# --- clean --apply ---
echo "=== memory clean --apply ==="
# skilled graduated entry should be removed; unbound graduated should stay
out=$($MEM clean --apply)
assert_contains "clean applied" "OK: cleaned" "$out"
assert "skilled entry removed, unbound stays" "1" "$(jq length "$DATA")"
assert "remaining is unbound" "none" "$(jq -r '.[0].skill' "$DATA")"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
