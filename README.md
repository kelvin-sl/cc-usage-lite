# cc-usage-lite

> Not affiliated with [ccusage](https://github.com/ccusage/ccusage). The name means "Claude Code usage, lite": the numbers you would put in a status line, without scanning transcripts.

A Claude Code status line in one short shell script. It reads only the JSON Claude Code passes on stdin, so it uses about 2 MB of memory and finishes in milliseconds, no matter how large your transcripts are or how many Claude Code windows you keep open. An optional variant also shows today's spend across every session, still without reading transcripts.

```
Opus 5.5 | ctx 42% | $3.14 | 5h 23% (14:00) | 7d 41% | my-app
```

model | context window used | this session's cost | 5-hour limit used (reset time) | 7-day limit used | current directory

With `statusline-today.sh`:

```
Opus 5.5 | ctx 42% | $3.14 | today $27.80 | 5h 23% (14:00) | 7d 41% | my-app
```

## Why another status line?

Claude Code runs your status line command again after every reply, in every open window. A status line that scans `~/.claude/projects` to work out today's total cost does that scan each time. With 11 GB of transcripts and six windows open, `ccusage statusline` held about 8 GB of memory on a 24 GB Mac.

Everything `statusline.sh` shows is already in the JSON Claude Code sends on stdin: `cost.total_cost_usd`, `context_window.used_percentage` and, on Pro/Max plans, `rate_limits.five_hour` and `rate_limits.seven_day` ([status line docs](https://code.claude.com/docs/en/statusline)). It formats those fields with one `jq` call.

## Install

Requirements: `jq` 1.6 or later (`brew install jq`, `apt install jq`).

Pick one script. `statusline.sh` is the minimal one; `statusline-today.sh` adds today's total.

```sh
curl -fsSL https://raw.githubusercontent.com/kelvin-sl/cc-usage-lite/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

For the today variant, replace `statusline.sh` with `statusline-today.sh` in the URL and keep the same output path.

Then add this to `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
```

Windows that are already open pick up the new command without a restart.

## What each field shows

| Field | Source on stdin | When it is missing |
|---|---|---|
| Model | `model.display_name` | `?` |
| `ctx 42%` | `context_window.used_percentage` | `ctx -` (for example before the first reply) |
| `$3.14` | `cost.total_cost_usd`, this session only | `$0` |
| `today $27.80` | today variant only: sum over today's sessions, see below | `today $0.00` |
| `5h 23% (14:00)` | `rate_limits.five_hour`, reset time in your local time zone | hidden (API key users, or before the first reply) |
| `7d 41%` | `rate_limits.seven_day` | hidden |
| Directory | last part of `workspace.current_dir` | empty |

If the input is not valid JSON, the line reads `statusline error`.

## How the today total works

Each time the status line runs, `statusline-today.sh` writes one line for its own session to `~/.cache/claude-statusline-cost/<date>/<session_id>` (or `$CLAUDE_COST_DIR`, or `$XDG_CACHE_HOME`): the session cost when first seen today, the latest cost, and anything banked before the counter went backwards. Today's total is the sum over today's files. Nothing reads transcripts.

- **Sessions that cross midnight.** Only the spend after midnight counts toward today.
- **Resumed sessions.** Cost carried over from before the resume is not counted again. If the counter restarts at 0 instead, the earlier spend is kept.
- **Several windows at once.** Each window writes only its own file, via a temp file and `mv`, so no locks are needed.
- **Cleanup.** The first run of each day deletes day directories older than yesterday. A day is a few KB.
- **Bad input.** A `session_id` outside `[A-Za-z0-9_-]` or a non-numeric cost is shown but not recorded.

What it counts differently from [ccusage](https://github.com/ccusage/ccusage):

- **Price source.** It sums Claude Code's own cost estimate. ccusage prices every message from the transcript with its own price table, so 1M-context, fast mode or tool pricing can differ.
- **Sessions without a status line are missing.** `claude -p`, the Agent SDK, Claude Desktop and the web app do not run the status line, so they are not counted. ccusage counts any transcript on disk.
- **No history.** It starts counting when you install it and keeps today and yesterday only. Use ccusage for weekly or monthly reports.
- **Last update can be missed.** If a background subagent finishes after your last reply and you close the window before the status line runs again, that spend is not recorded. Setting `refreshInterval` in the status line config reduces this.
- **Accounts are combined.** Use a different `CLAUDE_COST_DIR` per account to keep them apart.

It is an estimate of what this machine's interactive sessions spent today, not a bill. On a subscription you pay the plan price.

## Verification

### Automated tests

```sh
./test.sh
```

Runs both scripts on synthetic input in a temporary directory and compares the output. Cases covered:

- **`statusline.sh`.** Subscription input with rate limits, API-key input without them, an empty object, a string where the cost should be a number, and invalid JSON.
- **`statusline-today.sh`, totals.** Several sessions adding up; a resumed session whose earlier cost is not counted again; a session whose counter restarts at 0 without losing earlier spend.
- **`statusline-today.sh`, days.** A session crossing midnight counts only the part after midnight; day directories older than yesterday are removed.
- **`statusline-today.sh`, bad input.** Invalid JSON, empty stdin, a missing `session_id`, a `session_id` containing `../`, a string cost and a tiny float are shown but not recorded.
- **`statusline-today.sh`, concurrency.** Six windows updating 20 times each at the same moment produce the exact total, with no temp files left behind.

All pass on macOS with jq 1.7.1. Not yet run on Linux.

### Check against ccusage on your own machine

```sh
./compare-with-ccusage.sh
```

Prints today's total from the status line next to `ccusage claude daily` for today, and the difference. It needs ccusage installed and only reads. Expect the status line total to be lower if you installed it partway through the day, or if you also ran `claude -p`, the Agent SDK, Desktop or the web app today (see the list above).

## Comparison with similar tools

### What each tool reads and shows

| Tool | Reads | Today's total across sessions | Pace vs. reset time | Git status | Customisable layout |
|---|---|---|---|---|---|
| `statusline.sh` | stdin only | no | no | no | edit the script |
| `statusline-today.sh` | stdin + a few KB of its own files | yes, from status line runs | no | no | edit the script |
| [claude-pace](https://github.com/Astro-Han/claude-pace) | stdin + git (cached 5 s) | no | yes | yes | settings |
| [ccstatusline](https://github.com/sirmalloc/ccstatusline) | stdin + the current session's transcript | no | no | yes | interactive editor |
| [ccusage](https://github.com/ccusage/ccusage) `statusline` | every transcript on disk | yes, priced per message | no | no | flags |

### Memory and speed

Measured on 2026-11-18 on an Apple M4 Pro with 24 GB of memory and 11 GB of transcripts. Every tool got the same stdin JSON pointing at a 179 MB transcript; N copies were started at once with different session IDs to simulate N windows refreshing together. Figures are the sum of each process's peak memory (`/usr/bin/time -l`), default settings. `statusline-today.sh` was run with 40 session files already recorded for the day.

| Tool | 1 window | 3 windows | 6 windows | Time for 6 windows |
|---|---|---|---|---|
| `statusline.sh` | 2 MB | 7 MB | 15 MB | about 0.1 s |
| `statusline-today.sh` | 3 MB | 8 MB | 16 MB | about 0.1 s |
| [claude-pace](https://github.com/Astro-Han/claude-pace) | 7 MB | 20 MB | 41 MB | about 0.1 s |
| [ccstatusline](https://github.com/sirmalloc/ccstatusline) 2.2.34 | 200 MB | 586 MB | 1,217 MB | 0.5 s |
| [ccusage](https://github.com/ccusage/ccusage) 20.0.51 `statusline` | 2,502 MB | 4,015 MB | 7,995 MB | 20.5 s |

ccstatusline's memory follows the size of the current transcript (85 MB with a 444 KB transcript). ccusage caches its output, but the cache is invalidated whenever the transcript changes, which in an active window is almost every refresh.

Method, caveats and the full write-up: [Which Claude Code status line uses the least memory?](https://kelvinwang.info/en/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=cc-usage-lite) ([中文版](https://kelvinwang.info/zh-hant/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=cc-usage-lite))

### When to use something else

- **You want to know whether you will run out before the reset.** [claude-pace](https://github.com/Astro-Han/claude-pace) compares usage with elapsed time in each window and shows git status, for a few more MB.
- **You want many widgets, colours and an interactive layout editor.** [ccstatusline](https://github.com/sirmalloc/ccstatusline). Memory grows with long sessions.
- **You want exact per-message pricing, history, or weekly and monthly reports.** Run [ccusage](https://github.com/ccusage/ccusage) by hand (`ccusage claude daily`, `ccusage claude weekly`) instead of putting it in the status line.

## Customise

The output is a list joined by ` | `. Delete a line inside the `[ ... ]` block to drop a field, or add one using any field from the [stdin schema](https://code.claude.com/docs/en/statusline), for example:

```jq
("+" + (.cost.total_lines_added // 0 | tostring) + " -" + (.cost.total_lines_removed // 0 | tostring)),
```

To colour the whole line, pipe the output through `sed`, for example `| sed 's/^/\x1b[97m/;s/$/\x1b[0m/'` for bright white.

## Limitations

- `statusline.sh` shows this session's cost only. For a total, use `statusline-today.sh` or ccusage.
- The 5h/7d limits appear only on plans that send `rate_limits`, and only after the first reply in a session.
- POSIX `sh` + `jq`; on Windows use WSL or Git Bash.

## License

MIT
