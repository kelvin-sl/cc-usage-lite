#!/bin/sh
# cc-usage-lite: a Claude Code status line that reads only the JSON
# Claude Code passes on stdin. No transcript scanning, no network, no cache files.
# Shows: model | context % | session cost | 5h / 7d limit % | directory
# Requires: jq 1.6 or later.
jq -r '
  def pct: if . == null then "-" else (. | floor | tostring) + "%" end;
  def reset: if . == null then "" else " (" + (. | strflocaltime("%H:%M")) + ")" end;
  [
    (.model.display_name // "?"),
    ("ctx " + (.context_window.used_percentage | pct)),
    ("$" + (((.cost.total_cost_usd | numbers) // 0) * 100 | round / 100 | tostring)),
    (if .rate_limits.five_hour then
       "5h " + (.rate_limits.five_hour.used_percentage | pct) + (.rate_limits.five_hour.resets_at | reset)
     else empty end),
    (if .rate_limits.seven_day then
       "7d " + (.rate_limits.seven_day.used_percentage | pct)
     else empty end),
    ((.workspace.current_dir // .cwd // "") | split("/") | last)
  ] | join(" | ")
' 2>/dev/null || echo "statusline error"
