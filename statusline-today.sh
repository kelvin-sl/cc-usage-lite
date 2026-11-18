#!/bin/sh
# cc-usage-lite, "today" variant: statusline.sh plus "today $X",
# the sum of cost.total_cost_usd across every Claude Code session on this machine today.
# No transcript scanning. Each run records its own session in
#   $DIR/<YYYY-MM-DD>/<session_id>  ->  "base last carry"
# and today = sum(carry + last - base) over today's files.
#   base  = session cost when first seen today (yesterday's last value if it crossed midnight)
#   last  = latest cost seen
#   carry = spend banked before the counter went backwards (restarted without restoring cost)
DIR=${CLAUDE_COST_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline-cost}

# One jq call: line 1 = "session_id cost" (or "- -"), line 2 = formatted status line with a @TODAY@ slot.
out=$(jq -r '
  def pct: if . == null then "-" else (. | floor | tostring) + "%" end;
  def reset: if . == null then "" else " (" + (. | strflocaltime("%H:%M")) + ")" end;
  (if (.session_id | type) == "string" and (.session_id | test("^[A-Za-z0-9_-]{1,128}$"))
      and (.cost.total_cost_usd | type) == "number"
   then "\(.session_id) \(.cost.total_cost_usd)" else "- -" end),
  ([
    (.model.display_name // "?"),
    ("ctx " + (.context_window.used_percentage | pct)),
    ("$" + (((.cost.total_cost_usd | numbers) // 0) * 100 | round / 100 | tostring)),
    "@TODAY@",
    (if .rate_limits.five_hour then
       "5h " + (.rate_limits.five_hour.used_percentage | pct) + (.rate_limits.five_hour.resets_at | reset)
     else empty end),
    (if .rate_limits.seven_day then
       "7d " + (.rate_limits.seven_day.used_percentage | pct)
     else empty end),
    ((.workspace.current_dir // .cwd // "") | split("/") | last)
  ] | join(" | "))
' 2>/dev/null) || { echo "statusline error"; exit 0; }

sid=${out%%" "*}; rest=${out#*" "}; cost=${rest%%"
"*}; line=${out#*"
"}
day=$(date +%F)
D=$DIR/$day

case $out in *"
"*) ;; *) sid=- line=@TODAY@ ;; esac   # empty stdin -> jq printed nothing

if [ "$sid" != "-" ]; then
  if [ ! -d "$D" ]; then
    mkdir -p "$D" 2>/dev/null
    # First run of the day: drop day directories older than yesterday.
    # Day dirs hold only flat files, so no recursive removal is needed.
    yday=$(date -v-1d +%F 2>/dev/null || date -d yesterday +%F)
    for old in "$DIR"/????-??-??; do
      case ${old##*/} in "$day"|"$yday") ;; *) rm -f "$old"/* 2>/dev/null; rmdir "$old" 2>/dev/null ;; esac
    done
  fi
  f=$D/$sid
  if ! { [ -f "$f" ] && read -r base last carry < "$f"; }; then
    base=$cost carry=0
    # Session seen yesterday: start from yesterday's last value so spend after that counts today.
    y=$DIR/${yday:-$(date -v-1d +%F 2>/dev/null || date -d yesterday +%F)}/$sid
    [ -f "$y" ] && read -r _ base _ < "$y"
    last=$base
  fi
  # awk does the float math: bank the old segment when the counter went backwards.
  set -- $(awk -v b="$base" -v l="$last" -v c="$carry" -v x="$cost" \
    'BEGIN { if (x + 0 < l + 0) { c += l - b; b = 0 } print b, x, c }')
  printf '%s %s %s\n' "$1" "$2" "$3" > "$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f" 2>/dev/null
fi

total=$(awk 'FILENAME !~ /\.tmp$/ { t += $3 + $2 - $1 } END { printf "%.2f", t }' "$D"/* 2>/dev/null)
line=${line%%@TODAY@*}"today \$${total:-0.00}"${line#*@TODAY@}
printf '%s\n' "$line"
