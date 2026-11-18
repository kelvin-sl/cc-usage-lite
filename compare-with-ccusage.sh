#!/bin/sh
# Compares today's total from statusline-today.sh with ccusage's total for Claude Code today.
# Requires ccusage (npm install -g ccusage). Reads only; writes nothing.
DIR=${CLAUDE_COST_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline-cost}
D=$DIR/$(date +%F)
ours=$(awk 'FILENAME !~ /\.tmp$/ { t += $3 + $2 - $1; n++ } END { printf "%.2f %d", t, n }' "$D"/* 2>/dev/null)
[ -n "$ours" ] || ours="0.00 0"
command -v ccusage >/dev/null || { echo "ccusage not found: npm install -g ccusage"; exit 1; }
theirs=$(ccusage claude daily --json --since "$(date +%Y%m%d)" 2>/dev/null | jq -r '[.daily[].totalCost] | add // 0')
set -- $ours
awk -v a="$1" -v n="$2" -v b="$theirs" 'BEGIN {
  printf "statusline-today: $%.2f  (%d sessions seen by the status line)\n", a, n
  printf "ccusage claude:   $%.2f  (every transcript written today)\n", b
  if (b > 0) printf "difference:       $%.2f  (%.1f%% of ccusage)\n", a - b, (a - b) / b * 100
}'
