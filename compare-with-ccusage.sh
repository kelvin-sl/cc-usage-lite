#!/bin/sh
# Compares the observed daily estimate with ccusage's transcript-priced Claude Code total.
# This script does not change the status line cache; ccusage may manage its own caches.
export LC_ALL=C
fail() { printf '%s\n' "$*" >&2; exit 1; }
command -v ccusage >/dev/null || fail "ccusage not found: install ccusage before comparing"
command -v jq >/dev/null || fail "jq not found: install jq 1.6 or later"
DIR=${CLAUDE_COST_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline-cost}
D=$DIR/$(date +%F)
ours="0.00 0"
set -- "$D"/*
if [ -e "$1" ]; then
  ours=$(awk 'FILENAME !~ /\.tmp$/ { t += $3 + $2 - $1; n++ } END { printf "%.2f %d", t, n }' "$@") || fail "Cannot read the status line cache"
fi
day=$(date +%Y%m%d)
# Capture separately: POSIX sh pipelines otherwise hide a failed ccusage exit.
report=$(ccusage claude daily --json --since "$day" --until "$day") || fail "ccusage failed; comparison unavailable"
theirs=$(printf '%s' "$report" | jq -ers '
  if length != 1 then error("expected one JSON report") else .[0] end
  | if type != "object" then error("expected a report object") else . end
  | if (.daily | type) != "array" then error("expected a daily array") else .daily end
  | map(if type != "object" then error("expected a daily row") else .totalCost end
      | if type != "number" then error("expected numeric totalCost")
        elif (isfinite | not) or . < 0 then error("invalid totalCost") else . end)
  | add // 0
') || fail "Invalid ccusage report; comparison unavailable"
set -- $ours
awk -v a="$1" -v n="$2" -v b="$theirs" 'BEGIN {
  printf "statusline-today: $%.2f  (observed estimate; %d sessions)\n", a, n
  printf "ccusage claude:   $%.2f  (transcript-priced total for today)\n", b
  if (b > 0) printf "difference:       $%.2f  (%.1f%% of ccusage)\n", a - b, (a - b) / b * 100
}'
