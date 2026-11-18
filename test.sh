#!/bin/sh
# Runs statusline.sh on the example inputs and compares the output.
cd "$(dirname "$0")" || exit 1
export TZ=UTC
fail=0
check() { # name expected input
  got=$(printf '%s' "$3" | ./statusline.sh)
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1"; echo "  expected: $2"; echo "  got:      $got"; fail=1; fi
}
check "subscription" "Opus 5.5 | ctx 42% | \$3.14 | 5h 23% (14:00) | 7d 41% | my-app" "$(cat examples/subscription.json)"
check "api key, no rate limits, null context" "Sonnet 5.5 | ctx - | \$0.5 | my-app" "$(cat examples/api-key.json)"
check "empty object" "? | ctx - | \$0 | " "{}"
check "not JSON" "statusline error" "not json"
exit $fail
