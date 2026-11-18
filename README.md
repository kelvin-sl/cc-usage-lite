# cc-usage-lite

[![test](https://github.com/kelvin-sl/cc-usage-lite/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kelvin-sl/cc-usage-lite/actions/workflows/test.yml)
![shell](https://img.shields.io/badge/shell-POSIX%20sh-89e051)
![jq](https://img.shields.io/badge/jq-%E2%89%A51.6-blue)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

| Platform           | Shell      | jq      | Tested in CI |
| :----------------- | :--------- | :------ | :----------- |
| `Linux (x86_64)`   | POSIX `sh` | 1.6+    | ✓            |
| `macOS (ARM64)`    | POSIX `sh` | 1.6+    | ✓            |
| `Windows`          | WSL or Git Bash | 1.6+ | -          |

- **Write-up**: [Which Claude Code status line uses the least memory?](https://kelvinwang.info/en/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=cc-usage-lite) ([中文版](https://kelvinwang.info/zh-hant/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=cc-usage-lite))
- **Claude Code status line docs**: <https://code.claude.com/docs/en/statusline>
- **Issues**: <https://github.com/kelvin-sl/cc-usage-lite/issues>

## Introduction

cc-usage-lite is a Claude Code status line in one short shell script. It reads only the JSON
Claude Code passes on stdin, so it uses about 2 MB of memory and finishes in milliseconds,
however large your transcripts are and however many Claude Code windows you keep open.

```
Opus 5.5 | ctx 42% | $3.14 | 5h 23% (14:00) | 7d 41% | my-app
```

model | context window used | this session's cost | 5-hour limit used (reset time) | 7-day limit used | current directory

An optional variant, `statusline-today.sh`, also shows today's spend across every session on
the machine, still without reading transcripts:

```
Opus 5.5 | ctx 42% | $3.14 | today $27.80 | 5h 23% (14:00) | 7d 41% | my-app
```

## Features

- **Light**: One `jq` call per refresh. About 2 MB of memory per window, 15 MB for six windows.
- **Constant cost**: Never reads `~/.claude/projects`, so the cost does not grow with your history.
- **Offline**: No network calls, no daemons, no background processes.
- **Today's total (optional)**: `statusline-today.sh` sums every session's cost for the day from a few KB of its own files.
- **Safe with many windows**: Each window writes only its own file, atomically, so concurrent refreshes cannot corrupt the total.
- **Tested**: Automated tests on Linux and macOS, plus a script to check the total against ccusage on your own machine.

## Why cc-usage-lite?

Claude Code runs your status line command again after every reply, in every open window.
A status line that scans `~/.claude/projects` to work out today's total cost repeats that scan
each time. With 11 GB of transcripts and six windows open, `ccusage statusline` held about
8 GB of memory on a 24 GB Mac.

cc-usage-lite removes the scan.

Everything `statusline.sh` shows is already in the JSON Claude Code sends on stdin:
`cost.total_cost_usd`, `context_window.used_percentage` and, on Pro/Max plans,
`rate_limits.five_hour` and `rate_limits.seven_day`. The today variant records each session's
cost as it goes, so the daily total is a sum over a handful of small files instead of a pass
over every transcript.

## Scripts

| Script                                         | Shows                                     | Writes                                   | Status                                               |
| :--------------------------------------------- | :---------------------------------------- | :--------------------------------------- | :--------------------------------------------------- |
| [`statusline.sh`](statusline.sh)               | model, context, session cost, limits, dir | nothing                                  | ![status](https://img.shields.io/badge/stable-green) |
| [`statusline-today.sh`](statusline-today.sh)   | the above plus today's total              | `~/.cache/claude-statusline-cost/<date>/` | ![status](https://img.shields.io/badge/beta-yellow)  |
| [`compare-with-ccusage.sh`](compare-with-ccusage.sh) | today's total next to ccusage's     | nothing                                  | ![status](https://img.shields.io/badge/beta-yellow)  |
| [`test.sh`](test.sh)                           | test results                              | a temporary directory, removed on exit   | ![status](https://img.shields.io/badge/stable-green) |

### Status

- `beta`: Works and passes the automated tests; not yet compared with ccusage over full days of real use.
- `stable`: Output and behaviour are settled.

### Fields

| Field            | Source on stdin                                                | When it is missing                                   |
| :--------------- | :------------------------------------------------------------- | :--------------------------------------------------- |
| Model            | `model.display_name`                                           | `?`                                                  |
| `ctx 42%`        | `context_window.used_percentage`                               | `ctx -` (for example before the first reply)         |
| `$3.14`          | `cost.total_cost_usd`, this session only                       | `$0`                                                 |
| `today $27.80`   | today variant only: sum over today's sessions                  | `today $0.00`                                        |
| `5h 23% (14:00)` | `rate_limits.five_hour`, reset time in your local time zone    | hidden (API key users, or before the first reply)    |
| `7d 41%`         | `rate_limits.seven_day`                                        | hidden                                               |
| Directory        | last part of `workspace.current_dir`                           | empty                                                |

If the input is not valid JSON, the line reads `statusline error`.

## How the today total works

Each time the status line runs, `statusline-today.sh` writes one line for its own session to
`~/.cache/claude-statusline-cost/<date>/<session_id>` (or `$CLAUDE_COST_DIR`, or under
`$XDG_CACHE_HOME`): the session cost when first seen today, the latest cost, and anything
banked before the counter went backwards. Today's total is the sum over today's files.

- **Sessions that cross midnight**: Only the spend after midnight counts toward today.
- **Resumed sessions**: Cost carried over from before the resume is not counted again. If the counter restarts at 0 instead, the earlier spend is kept.
- **Several windows at once**: Each window writes only its own file, via a temp file and `mv`, so no locks are needed.
- **Cleanup**: The first run of each day deletes day directories older than yesterday. A day is a few KB.
- **Bad input**: A `session_id` outside `[A-Za-z0-9_-]` or a non-numeric cost is shown but not recorded.

What it counts differently from [ccusage](https://github.com/ccusage/ccusage):

- **Price source**: It sums Claude Code's own cost estimate. ccusage prices every message from the transcript with its own price table, so 1M-context, fast mode or tool pricing can differ.
- **Sessions without a status line**: `claude -p`, the Agent SDK, Claude Desktop and the web app do not run the status line, so they are not counted. ccusage counts any transcript on disk.
- **History**: It starts counting when you install it and keeps today and yesterday only. Use ccusage for weekly or monthly reports.
- **Last update**: If a background subagent finishes after your last reply and you close the window before the status line runs again, that spend is not recorded. Setting `refreshInterval` in the status line config reduces this.
- **Accounts**: Combined. Use a different `CLAUDE_COST_DIR` per account to keep them apart.

> [!WARNING]
>
> The today total is an estimate of what this machine's interactive sessions spent, not a bill.
> On a subscription you pay the plan price.

## Comparison with similar tools

### What each tool reads and shows

| Tool                                                        | Reads                                    | Today's total across sessions | Pace vs. reset time | Git status | Layout             |
| :---------------------------------------------------------- | :--------------------------------------- | :---------------------------- | :------------------ | :--------- | :----------------- |
| `statusline.sh`                                             | stdin only                               | -                             | -                   | -          | edit the script    |
| `statusline-today.sh`                                       | stdin + a few KB of its own files        | ✓ from status line runs       | -                   | -          | edit the script    |
| [claude-pace](https://github.com/Astro-Han/claude-pace)     | stdin + git (cached 5 s)                 | -                             | ✓                   | ✓          | settings           |
| [ccstatusline](https://github.com/sirmalloc/ccstatusline)   | stdin + the current session's transcript | -                             | -                   | ✓          | interactive editor |
| [ccusage](https://github.com/ccusage/ccusage) `statusline`  | every transcript on disk                 | ✓ priced per message          | -                   | -          | flags              |

### Memory and speed

Measured on 2026-11-18 on an Apple M4 Pro with 24 GB of memory and 11 GB of transcripts.
Every tool got the same stdin JSON pointing at a 179 MB transcript; N copies were started at
once with different session IDs to simulate N windows refreshing together. Figures are the sum
of each process's peak memory (`/usr/bin/time -l`), default settings. `statusline-today.sh`
was run with 40 session files already recorded for the day.

| Tool                                                                 | 1 window | 3 windows | 6 windows | Time for 6 windows |
| :------------------------------------------------------------------- | -------: | --------: | --------: | -----------------: |
| `statusline.sh`                                                      | 2 MB     | 7 MB      | 15 MB     | about 0.1 s        |
| `statusline-today.sh`                                                | 3 MB     | 8 MB      | 16 MB     | about 0.1 s        |
| [claude-pace](https://github.com/Astro-Han/claude-pace)              | 7 MB     | 20 MB     | 41 MB     | about 0.1 s        |
| [ccstatusline](https://github.com/sirmalloc/ccstatusline) 2.2.34     | 200 MB   | 586 MB    | 1,217 MB  | 0.5 s              |
| [ccusage](https://github.com/ccusage/ccusage) 20.0.51 `statusline`   | 2,502 MB | 4,015 MB  | 7,995 MB  | 20.5 s             |

ccstatusline's memory follows the size of the current transcript (85 MB with a 444 KB
transcript). ccusage caches its output, but the cache is invalidated whenever the transcript
changes, which in an active window is almost every refresh.

### When to use something else

- **Pace**: To know whether you will run out before the reset, use [claude-pace](https://github.com/Astro-Han/claude-pace). It compares usage with elapsed time and shows git status, for a few more MB.
- **Widgets**: For many widgets, colours and an interactive layout editor, use [ccstatusline](https://github.com/sirmalloc/ccstatusline). Memory grows with long sessions.
- **Reports**: For exact per-message pricing, history, or weekly and monthly reports, run [ccusage](https://github.com/ccusage/ccusage) by hand (`ccusage claude daily`, `ccusage claude weekly`) instead of putting it in the status line.

## Roadmap

The project stays a single-file status line that reads stdin and nothing else of size.
Priorities are keeping it small, keeping the today total honest against ccusage, and fixing
anything that breaks when Claude Code changes its stdin schema.

Colour themes, multi-line layouts, git integration, pace calculations and historical reports
are out of scope; the tools in [When to use something else](#when-to-use-something-else)
already do them well.

## Security

- **No network**: Neither script makes network calls.
- **Writes**: `statusline.sh` writes nothing. `statusline-today.sh` writes only under its cache directory, using file names checked against `[A-Za-z0-9_-]`, so a crafted `session_id` cannot write elsewhere.
- **Deletes**: Only the day directories it created, older than yesterday, file by file with `rm -f` and `rmdir` (no recursive delete).
- **Reads**: Only stdin and its own cache files. Transcripts are never opened.

Report a security problem through a [private advisory](https://github.com/kelvin-sl/cc-usage-lite/security/advisories/new) rather than a public issue.

## Versioning and releases

> [!WARNING]
>
> **cc-usage-lite is young.** Output formats may change between commits, especially in the beta scripts.

`main` is always the release. The install commands below fetch the latest `main`.

## Installation

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

## Customisation

The output is a list joined by ` | `. Delete a line inside the `[ ... ]` block to drop a field,
or add one using any field from the [stdin schema](https://code.claude.com/docs/en/statusline), for example:

```jq
("+" + (.cost.total_lines_added // 0 | tostring) + " -" + (.cost.total_lines_removed // 0 | tostring)),
```

To colour the whole line, pipe the output through `sed`, for example
`| sed 's/^/\x1b[97m/;s/$/\x1b[0m/'` for bright white.

## Verification

### Automated tests

```sh
./test.sh
```

Runs both scripts on synthetic input in a temporary directory and compares the output.
[CI](https://github.com/kelvin-sl/cc-usage-lite/actions/workflows/test.yml) runs the same
command on Linux and macOS for every push and pull request.

- **`statusline.sh`**: Subscription input with rate limits, API-key input without them, an empty object, a string where the cost should be a number, and invalid JSON.
- **Totals**: Several sessions adding up; a resumed session whose earlier cost is not counted again; a session whose counter restarts at 0 without losing earlier spend.
- **Days**: A session crossing midnight counts only the part after midnight; day directories older than yesterday are removed.
- **Bad input**: Invalid JSON, empty stdin, a missing `session_id`, a `session_id` containing `../`, a string cost and a tiny float are shown but not recorded.
- **Concurrency**: Six windows updating 20 times each at the same moment produce the exact total, with no temp files left behind.

### Check against ccusage on your own machine

```sh
./compare-with-ccusage.sh
```

Prints today's total from the status line next to `ccusage claude daily` for today, and the
difference. It needs ccusage installed and only reads. Expect the status line total to be lower
if you installed it partway through the day, or if you also ran `claude -p`, the Agent SDK,
Desktop or the web app today.

## Contributing

Bug reports and small fixes are welcome. Open an
[issue](https://github.com/kelvin-sl/cc-usage-lite/issues) with the stdin JSON that produced
the wrong output (remove anything private), what you expected, and your `jq --version`.

> [!NOTE]
>
> Pull requests should keep `./test.sh` passing and add a test case for the behaviour they change.
> Features listed as out of scope in the [Roadmap](#roadmap) will be declined.

## License

The source code for cc-usage-lite is available under the [MIT License](LICENSE).
