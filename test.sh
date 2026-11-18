#!/bin/sh
# Tests for statusline.sh and statusline-today.sh with synthetic stdin.
# Writes only to a temporary directory, which is removed at the end.
cd "$(dirname "$0")" || exit 1
H=$(pwd)
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
export TZ=UTC
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1"; echo "  expected: $2"; echo "  got:      $3"; fail=1; fi; }

echo "== statusline.sh"
base() { printf '%s' "$1" | ./statusline.sh; }
check "subscription" "Opus 5.5 | ctx 42% | \$3.14 | 5h 23% (14:00) | 7d 41% | my-app" "$(base "$(cat examples/subscription.json)")"
check "api key, no rate limits, null context" "Sonnet 5.5 | ctx - | \$0.5 | my-app" "$(base "$(cat examples/api-key.json)")"
check "empty object" "? | ctx - | \$0 | " "$(base '{}')"
check "cost is a string" "? | ctx - | \$0 | " "$(base '{"cost":{"total_cost_usd":"5"}}')"
check "not JSON" "statusline error" "$(base 'not json')"

echo "== statusline-today.sh"
# Fake `date` so the tests can move between days.
mkdir -p "$T/bin"
cat > "$T/bin/date" <<'EOS'
#!/bin/sh
case "$*" in *-v-1d*|*yesterday*) echo "$FAKE_YDAY" ;; *) echo "$FAKE_DAY" ;; esac
EOS
chmod +x "$T/bin/date"
export PATH="$T/bin:$PATH" CLAUDE_COST_DIR="$T/cache"
run() { printf '{"session_id":"%s","cost":{"total_cost_usd":%s},"model":{"display_name":"Opus"},"workspace":{"current_dir":"/x/proj"}}' "$1" "$2" | "$H/statusline-today.sh"; }
today() { run "$@" | sed 's/.*today \$\([0-9.]*\).*/\1/'; }
only() { sed 's/.*today \$\([0-9.]*\).*/\1/'; }
fresh() { rm -rf "$CLAUDE_COST_DIR"; }

fresh; export FAKE_DAY=2026-11-18 FAKE_YDAY=2026-11-17
check "full line" "Opus | ctx - | \$0 | today \$0.00 | proj" "$(run aaa 0)"
check "A spends 1.50" 1.50 "$(today aaa 1.5)"
today bbb 0 >/dev/null
check "B spends 2.25, total adds up" 3.75 "$(today bbb 2.25)"
check "C resumed with 10.00 already spent: not counted" 3.75 "$(today ccc 10)"
check "C spends 0.50 more" 4.25 "$(today ccc 10.5)"
check "A restarted, counter back to 0.30: earlier 1.50 kept" 4.55 "$(today aaa 0.3)"
check "A continues to 1.00" 5.25 "$(today aaa 1.0)"

fresh; export FAKE_DAY=2026-11-17 FAKE_YDAY=2026-11-16
today mmm 0 >/dev/null
check "day 1: session reaches 7.00" 7.00 "$(today mmm 7)"
export FAKE_DAY=2026-11-18 FAKE_YDAY=2026-11-17
check "day 2: 7.40 counts only the 0.40 after midnight" 0.40 "$(today mmm 7.4)"
check "day 2: 9.00" 2.00 "$(today mmm 9)"

mkdir -p "$CLAUDE_COST_DIR/2026-11-10" && echo "0 5 0" > "$CLAUDE_COST_DIR/2026-11-10/old"
export FAKE_DAY=2026-11-19 FAKE_YDAY=2026-11-18
today zzz 0 >/dev/null
check "day directories older than yesterday are removed" "2026-11-18 2026-11-19" "$(ls "$CLAUDE_COST_DIR" | tr '\n' ' ' | sed 's/ $//')"

fresh; export FAKE_DAY=2026-11-18 FAKE_YDAY=2026-11-17
today aaa 0 >/dev/null; today aaa 2 >/dev/null
check "not JSON" "statusline error" "$(echo 'not json' | ./statusline-today.sh)"
check "empty stdin: total unchanged" 2.00 "$(printf '' | ./statusline-today.sh | only)"
check "no session_id: not recorded" 2.00 "$(echo '{"cost":{"total_cost_usd":5}}' | ./statusline-today.sh | only)"
check "session_id with ../: not recorded" 2.00 "$(echo '{"session_id":"../../etc","cost":{"total_cost_usd":5}}' | ./statusline-today.sh | only)"
check "cost is a string: not recorded" 2.00 "$(echo '{"session_id":"q","cost":{"total_cost_usd":"5"}}' | ./statusline-today.sh | only)"
check "tiny float 1e-05" 2.00 "$(today tiny 1e-05 >/dev/null; today tiny 0.00001)"

fresh
i=1; while [ $i -le 6 ]; do
  ( n=1; while [ $n -le 20 ]; do today "win$i" "$n" >/dev/null; n=$((n+1)); done ) &
  i=$((i+1))
done; wait
check "6 windows x 20 updates at once: total 6 x 19" 114.00 "$(today win1 20)"
check "no leftover temp files" 0 "$(ls "$CLAUDE_COST_DIR/2026-11-18" | grep -c tmp)"

[ $fail = 0 ] && echo "all tests passed"
exit $fail
