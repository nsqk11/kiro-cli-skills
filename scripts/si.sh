#!/bin/bash
# si — self-improving single-file CLI
# Data: .data/si.json (array of entries)
# Lifecycle: open → done → graduated

set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$SKILL_DIR/.data/si.json"
[ -f "$DATA" ] || echo '[]' > "$DATA"

cmd="${1:-help}"; shift || true

gen_id() { printf '%s%03d' "$(date +%Y%m%d)" "$(( $(jq "[.[] | select(.id | startswith(\"$(date +%Y%m%d)\"))] | length" "$DATA") + 1 ))"; }

case "$cmd" in
add)
  type="" kw="" summary="" detail=""
  while getopts "t:k:s:d:" o; do
    case $o in t) type="$OPTARG";; k) kw="$OPTARG";; s) summary="$OPTARG";; d) detail="$OPTARG";; esac
  done
  [ -z "$type" ] || [ -z "$summary" ] && { echo "ERR: -t type and -s summary required"; exit 1; }

  if [ -n "$kw" ]; then
    IFS=',' read -ra KWS <<< "$kw"
    for k in "${KWS[@]}"; do
      hits=$(jq -r --arg k "$k" '[.[] | select(.keywords[] | ascii_downcase | contains($k | ascii_downcase))] | length' "$DATA")
      if [ "$hits" -gt 0 ]; then
        echo "DUPLICATE: keyword '$k' found in $hits existing entries:"
        jq -r --arg k "$k" '.[] | select(.keywords[] | ascii_downcase | contains($k | ascii_downcase)) | "  [\(.id)] \(.status) \(.type): \(.summary)"' "$DATA"
        echo "Use --force or different keywords."
        [[ " $* " == *" --force "* ]] || exit 2
      fi
    done
  fi

  id="$(gen_id)"
  kw_json=$(echo "$kw" | jq -R 'split(",") | map(gsub("^ +| +$";""))')
  jq --arg id "$id" --arg date "$(date +%Y-%m-%d)" --arg type "$type" \
     --argjson kw "$kw_json" --arg s "$summary" --arg d "$detail" \
     '. += [{"id":$id,"date":$date,"type":$type,"status":"open","keywords":$kw,"summary":$s,"detail":$d,"section":null,"skill":null}]' \
     "$DATA" > "$DATA.tmp" && mv -f "$DATA.tmp" "$DATA"
  echo "OK: added $id"
  ;;

resolve)
  id="" res=""
  while getopts "i:r:" o; do case $o in i) id="$OPTARG";; r) res="$OPTARG";; esac; done
  [ -z "$id" ] && { echo "ERR: -i id required"; exit 1; }
  jq --arg id "$id" --arg r "$res" \
     'map(if .id == $id then .status = "done" | .resolution = $r else . end)' \
     "$DATA" > "$DATA.tmp" && mv -f "$DATA.tmp" "$DATA"
  echo "OK: $id → done"
  ;;

graduate)
  id="" section="" skill="none"
  while getopts "i:S:k:" o; do case $o in i) id="$OPTARG";; S) section="$OPTARG";; k) skill="$OPTARG";; esac; done
  [ -z "$id" ] || [ -z "$section" ] && { echo "ERR: -i id and -S section required"; exit 1; }
  jq --arg id "$id" --arg sec "$section" --arg sk "$skill" \
     'map(if .id == $id then .status = "graduated" | .section = $sec | .skill = $sk else . end)' \
     "$DATA" > "$DATA.tmp" && mv -f "$DATA.tmp" "$DATA"
  echo "OK: $id → graduated [section=$section, skill=$skill]"
  ;;

list)
  filter="."
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) filter="$filter | select(.status==\"$2\")"; shift 2;;
      --skill)  filter="$filter | select(.skill==\"$2\")"; shift 2;;
      --type)   filter="$filter | select(.type==\"$2\")"; shift 2;;
      *) shift;;
    esac
  done
  jq -r ".[] | $filter | \"[\(.id)] \(.status) \(.type): \(.summary)\"" "$DATA"
  ;;

search)
  kw=""
  while getopts "k:" o; do case $o in k) kw="$OPTARG";; esac; done
  [ -z "$kw" ] && { echo "ERR: -k keyword required"; exit 1; }
  jq -r --arg k "$kw" '.[] | select((.keywords[]? | ascii_downcase | contains($k | ascii_downcase)) or (.summary | ascii_downcase | contains($k | ascii_downcase))) | "[\(.id)] \(.status) \(.type): \(.summary)"' "$DATA"
  ;;

memory)
  jq -r '.[] | select(.status=="graduated" and .skill=="none") | "[\(.section)] \(.summary)"' "$DATA"
  ;;

help)
  cat <<'EOF'
si — self-improving CLI
  add      -t TYPE -k "kw,..." -s "summary" [-d "detail"]
  resolve  -i ID [-r "resolution"]
  graduate -i ID -S "section" [-k "skill-name"]
  list     [--status S] [--skill S] [--type T]
  search   -k "keyword"
  memory   (graduated + skill:none for context loading)
EOF
  ;;

*) echo "Unknown command: $cmd. Run: si help"; exit 1;;
esac
