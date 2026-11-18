# cc-usage-lite

[![test](https://github.com/kelvin-sl/cc-usage-lite/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kelvin-sl/cc-usage-lite/actions/workflows/test.yml)
![shell](https://img.shields.io/badge/shell-POSIX%20sh-89e051)
![jq](https://img.shields.io/badge/jq-%E2%89%A51.6-blue)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**A lightweight replacement for `ccusage statusline`. Keep ccusage for your reports.**

See your model, context usage, session cost and available rate limits without scanning
conversation history. One shell script, one `jq` call per refresh. No Node/Bun runtime,
network requests or background service for the status line.

```text
Opus 5.5 | ctx 42% | $3.14 | 5h 23% (14:00) | 7d 41% | my-app
```

The main script's work does not grow with transcript history. In the
[reproducible macOS sample](#benchmark), its reported peak RSS was about 2.2 MiB per invocation.
An optional beta script adds an [observed daily estimate](#optional-observed-daily-estimate).

**Choose your starting point:**

- [Start from zero](#start-from-zero)
- [Switch from ccusage](#switch-from-ccusage)
- [Switch from another status line](#switch-from-another-status-line)
- [Restore your previous setup](#restore-or-uninstall)

## Start from zero

### 1. Check your environment

You need Claude Code, a POSIX shell, `curl` and **jq 1.6+**.

| Environment | Setup | Automated coverage |
| :---------- | :---- | :----------------- |
| macOS | Install jq with `brew install jq` | Script tests on macOS |
| Linux | On Debian/Ubuntu: `sudo apt install jq curl` | Script tests, including jq 1.6 with dash |
| Windows with Git Bash | Install [Git for Windows](https://gitforwindows.org/) and [jq](https://jqlang.org/download/); run these instructions in **Git Bash** | Script tests in Windows Git Bash |
| Windows with WSL | Install Claude Code and dependencies **inside the same WSL distribution**, then follow Linux steps | No dedicated WSL integration test |

On Windows, make sure `jq --version` succeeds inside Git Bash. Reopen the terminal after
changing PATH. These `.sh` files are not native PowerShell/CMD scripts. Claude Code's
[Windows status line documentation](https://code.claude.com/docs/en/statusline#windows-configuration)
explains shell selection and path quoting.

CI checks the scripts; it does **not** launch an interactive Claude Code session on each OS.
The preview and live checks below are still necessary.

### 2. Download and preview

These commands use the default `~/.claude` directory. If you use a custom `CLAUDE_CONFIG_DIR`,
use that directory for both the script and settings, and adjust the command accordingly.

```sh
mkdir -p "$HOME/.claude"
curl -fsSL https://raw.githubusercontent.com/kelvin-sl/cc-usage-lite/main/statusline.sh -o "$HOME/.claude/cc-usage-lite.sh"
chmod +x "$HOME/.claude/cc-usage-lite.sh"
printf '%s
' '{"model":{"display_name":"Preview"},"context_window":{"used_percentage":42},"cost":{"total_cost_usd":3.14},"workspace":{"current_dir":"/projects/my-app"}}' | sh "$HOME/.claude/cc-usage-lite.sh"
```

Expected preview:

```text
Preview | ctx 42% | $3.14 | my-app
```

The dedicated filename leaves an existing `statusline.sh` alone. Downloading again updates
`cc-usage-lite.sh`; save a copy first if you customized that file.

### 3. Configure Claude Code

If `~/.claude/settings.json` does **not** exist, create it with this complete JSON:

```json
{
  "statusLine": {
    "type": "command",
    "command": "sh \"$HOME/.claude/cc-usage-lite.sh\""
  }
}
```

If it already exists, [back it up](#back-up-settings), then edit only the `statusLine` field.
Preserve your other settings and keep the file valid JSON. You can check it with:

```sh
jq empty "$HOME/.claude/settings.json"
```

Claude Code picks up a changed status line command without a restart. Send a message in a
trusted project and check the line after the reply. `ctx -` can appear before usage is
available; rate-limit fields are hidden when Claude Code does not provide them.

If it stays blank, run the preview again and check the configured path, jq availability,
and any project or managed settings overriding your user configuration.

## Switch from ccusage

You can keep ccusage installed for `ccusage claude daily`, weekly and monthly reports.
Only replace its status line command.

1. [Back up your settings](#back-up-settings).
2. Follow [Download and preview](#2-download-and-preview).
3. Find the existing `statusLine` object in your active settings. Replace its `command`
   (`npx -y ccusage statusline`, `bun x ccusage statusline`, a wrapper, etc.) with
   `sh "$HOME/.claude/cc-usage-lite.sh"`, escaped as shown in the JSON above. Keep unrelated
   settings and optional layout fields such as `padding`.
4. Send a message and verify the live line. To go back, restore the saved `statusLine` object.

| After switching to the main script | What changes |
| :-------------------------------- | :----------- |
| Model, context percentage, session cost | Read directly from Claude Code stdin |
| 5-hour / 7-day rate-limit percentages | Shown when supplied by Claude Code; these are not ccusage's billing-block estimates |
| Today's transcript total, block cost, burn rate | Not provided; use ccusage reports or the optional observed estimate |
| Historical reports and existing transcripts | Remain available to ccusage; no data migration or deletion |

Do not expect the optional `today` number to match ccusage: the two tools observe and price
different data. See [the estimate's limits](#optional-observed-daily-estimate).

## Switch from another status line

The same process applies to ccstatusline, claude-pace, custom scripts and other tools that
set Claude Code's `statusLine.command`.

1. [Back up your settings](#back-up-settings), including the complete old `statusLine` object.
2. Download to the dedicated `cc-usage-lite.sh` filename and run the preview.
3. Replace only the active `statusLine.command`, using the JSON example above. Leave the old
   tool's executable, config files, plugins and any unrelated hooks in place.
4. Check the live output. Git widgets, themes, pace calculations and custom layouts from
   the old tool are not imported. Restore the old object if you prefer those features.

If a tool regenerates your settings, stop its status-line configuration step from overwriting
this command. Tools configured through other mechanisms need their own instructions; this
is a migration of Claude Code's status line setting, not a universal uninstaller.

### Back up settings

In macOS/Linux/WSL or Git Bash, this creates a uniquely named copy and prints its path:

```sh
backup=$(mktemp "$HOME/.claude/settings.json.before-cc-usage-lite.XXXXXX") &&
  cp -p "$HOME/.claude/settings.json" "$backup" &&
  printf 'Settings backup: %s\n' "$backup"
```

Run this only when the settings file exists. Save the printed path; it also preserves
any custom status line options you may want to restore later.

### Restore or uninstall

- **Previously used another status line:** copy the `statusLine` object from your saved
  settings back into the active file. Restore the whole backup only if you have made no
  other settings changes since taking it.
- **Started without a status line:** remove just the `statusLine` field from settings.
- After switching the command away, you may remove `~/.claude/cc-usage-lite.sh`.
  The optional daily cache can be left in place or removed separately after checking its path;
  it is not automatically cleaned once the daily script stops running.

## Optional observed daily estimate

`statusline-today.sh` adds this field while keeping the same installation and output format:

```text
Opus 5.5 | ctx 42% | $3.14 | today $27.80 | 5h 23% (14:00) | 7d 41% | my-app
```

To select it, replace `main/statusline.sh` in the download URL with
`main/statusline-today.sh`, keeping the destination `cc-usage-lite.sh`. The settings stay the same.

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

### Compare with ccusage

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

## Benchmark

Run a reproducible comparison with Python 3.10+, jq and a POSIX shell. Python is needed only
for this development tool, not for the installed status line. No packages are downloaded.

```sh
python3 benchmarks/benchmark.py --ccusage --output /tmp/cc-usage-benchmark.json
```

Omit `--ccusage` to measure only the two local scripts. Choose a fresh output path on each
run. See [methodology and commands](benchmarks/README.md) for larger datasets and limitations.

Sample from macOS ARM64, 2026-11-18: 32 MiB generated transcripts across 40 sessions,
3 repetitions, jq 1.7.1-apple, ccusage 20.0.51. Values below are medians, not guarantees.
[Raw samples, versions, commands and source hashes](benchmarks/results/2026-11-18-macos-arm64.json).

| Tool / cache condition | 1-window batch | 6-window batch | Per-invocation peak RSS, 6-window runs |
| :--------------------- | -------------: | -------------: | -----------------------------------: |
| `statusline.sh` | 10 ms | 21 ms | 2.16 MiB |
| `statusline-today.sh` | 23 ms | 30 ms | 2.31 MiB |
| ccusage, cache disabled | 162 ms | 333 ms | 78.41 MiB |
| ccusage, primed with unchanged input | 42 ms | 146 ms | 46.97 MiB |

RSS is the per-invocation value reported by `/usr/bin/time`, **not simultaneous whole-process-tree
memory and not a sum of six peaks**. Batch time includes process launch and harness overhead.
The primed condition uses a one-hour cache interval, not ccusage's default; the cache-disabled
condition measures repeated work. Neither simulates a complete live Claude Code workload.
The two tools provide different features. Small synthetic workloads do not prove savings
for every machine or reproduce the earlier 11 GB personal-history experiment.

## Fields and customization

| Field | Source | Missing value |
| :---- | :----- | :------------ |
| Model | `model.display_name` | `?` |
| Context | `context_window.used_percentage` | `ctx -` |
| Session cost | `cost.total_cost_usd` | `$0` |
| 5h usage and local reset time | `rate_limits.five_hour` | Hidden |
| 7d usage | `rate_limits.seven_day` | Hidden |
| Directory | `workspace.current_dir`, then `cwd` | Empty |

Invalid JSON prints `statusline error`. Remove a field from the script's `[ ... ]` list to
hide it. Other available values are documented in the
[Claude Code stdin schema](https://code.claude.com/docs/en/statusline#available-data).

## Scope and alternatives

The project stays small and independent of transcript size. Historical reports, git widgets,
pace calculations, themes and layout editors are out of scope.

- [ccusage](https://github.com/ccusage/ccusage): historical usage and cost reports.
- [claude-pace](https://github.com/Astro-Han/claude-pace): pace and reset-time guidance.
- [ccstatusline](https://github.com/sirmalloc/ccstatusline): configurable widgets and layouts.

Background write-up: [Which Claude Code status line uses the least memory?](https://kelvinwang.info/en/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=cc-usage-lite)
([中文版](https://kelvinwang.info/zh-hant/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=cc-usage-lite)).
Use the benchmark above for the checked-in, reproducible measurements.

## Verification and contributing

```sh
./test.sh
python3 -m unittest discover -s benchmarks -p 'test_*.py'
```

Tests cover formatting, cost accumulation, first-observation baselines, approximate midnight
assignment, counter resets, invalid input, retention, concurrent distinct sessions, and
comparison-command failures. The benchmark validates synthetic message counts against the
installed ccusage before timing it. CI also runs a small local-script benchmark smoke test.

[Bug reports](https://github.com/kelvin-sl/cc-usage-lite/issues) and small fixes are welcome.
Include your OS, shell, jq version, expected output and sanitized sample stdin. Add a test
for changed behavior. If the tool helps your daily workflow, a GitHub star helps others find it.

## Security and updates

The main script reads stdin and writes nothing. The optional daily script reads/writes only
its cache, validates session filenames, and cleans old date-shaped directories there. Use a
dedicated cache directory. Neither status line script makes network calls or opens transcripts.
Report vulnerabilities through a [private advisory](https://github.com/kelvin-sl/cc-usage-lite/security/advisories/new).

Installation currently follows `main`. To pin a reviewed revision, replace `main` in the
raw download URL with its full commit SHA. Save custom edits before updating; output of the
beta scripts may evolve. No automatic updater is installed.

## License

[MIT](LICENSE).
