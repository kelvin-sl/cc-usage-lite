# Optional observed daily estimate

`statusline-today.sh` adds this field while keeping the same installation and output format:

```text
Opus 5.5 | ctx 42% | $3.14 | today $27.80 | 5h 23% (14:00) | 7d 41% | my-app
```

Follow the [installation guide](getting-started.md) first. To select this variant, replace
`main/statusline.sh` in the download URL with `main/statusline-today.sh`, keeping the
destination `cc-usage-lite.sh`. The settings stay the same. With the Windows installer,
use `-Today`.

**`today` is an estimate from observed cost increments assigned to the local day, not a
complete daily total or a bill.** On a subscription you pay the plan price. This variant
remains beta; it has not been reconciled across full days of real use.

Each refresh stores `base last carry` for its session in
`~/.cache/claude-statusline-cost/<date>/<session_id>`. `CLAUDE_COST_DIR` overrides the cache
root; otherwise `XDG_CACHE_HOME` is respected. The displayed estimate sums
`carry + last - base` across that day's files.

- **First observation:** the current cost becomes the baseline. If the first observation
  is `$1.00`, `today` starts at `$0.00`; a later `$1.50` adds `$0.50`. This can omit the first
  reply of a new session as well as work done before installation.
- **Midnight:** yesterday's last observed cost becomes the next day's baseline. The entire
  delta goes to the new day, even if some work happened before midnight. For example,
  last observed `$2`, actual midnight cost `$3`, next observed `$4`: the script assigns `$2`
  to today, although only `$1` was spent after midnight. Stdin snapshots cannot recover the split.
- **Resumes and counter resets:** an unseen session starts from its first observed cost;
  a decreasing counter banks the earlier observed increment, then counts from zero.
- **Coverage:** sessions without status line updates, such as headless CLI or SDK usage,
  are not counted. Work after the final refresh is missed. A `refreshInterval` can reduce
  observation gaps, but does not make the midnight split exact.
- **Pricing:** uses Claude Code's cumulative cost estimate. ccusage can price transcript
  messages using its own tables, so even fully observed increments may differ.
- **Multiple windows:** different session IDs write separate files via temporary files and
  rename. This does not promise serialized updates for two processes sharing one session ID.
- **Retention and accounts:** keeps today and yesterday; older day directories are cleaned
  on the first run of a new day. Accounts are combined unless you set separate `CLAUDE_COST_DIR`s.

## Compare with ccusage

From a checkout, with ccusage already installed:

```sh
./compare-with-ccusage.sh
```

It prints the observed estimate, ccusage's Claude Code total for the same local date, and
the difference when ccusage's total is positive. Keep ccusage's reporting timezone aligned
with your machine if you customize its configuration. The difference is a diagnostic,
not a correctness score: first observations, missing sessions, midnight assignment and
pricing can all affect it in either direction.

A failed command or invalid report produces an error on stderr and exits nonzero, without
printing fabricated totals. A valid `daily: []` report is treated as zero. The script does
not modify the status line cache; ccusage may update its own pricing/cache files.

[Back to the project](../README.md)
