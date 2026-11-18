# claude-code-statusline-lite

A Claude Code status line in one 20-line shell script. It reads only the JSON Claude Code passes on stdin, so it uses about 2 MB of memory and finishes in milliseconds, no matter how large your transcripts are or how many Claude Code windows you keep open.

```
Opus 5.5 | ctx 42% | $3.14 | 5h 23% (14:00) | 7d 41% | my-app
```

model | context window used | this session's cost | 5-hour limit used (reset time) | 7-day limit used | current directory

## Why another status line?

Claude Code runs your status line command again after every reply, in every open window. A status line that scans `~/.claude/projects` to work out today's total cost does that scan each time. With 11 GB of transcripts and six windows open, `ccusage statusline` held about 8 GB of memory on a 24 GB Mac.

Everything this script shows is already in the JSON Claude Code sends on stdin: `cost.total_cost_usd`, `context_window.used_percentage` and, on Pro/Max plans, `rate_limits.five_hour` and `rate_limits.seven_day` ([status line docs](https://code.claude.com/docs/en/statusline)). It just formats those fields with one `jq` call.

## Install

Requirements: `jq` 1.6 or later (`brew install jq`, `apt install jq`).

```sh
curl -fsSL https://raw.githubusercontent.com/kelvin-sl/claude-code-statusline-lite/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

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
| `5h 23% (14:00)` | `rate_limits.five_hour`, reset time in your local time zone | hidden (API key users, or before the first reply) |
| `7d 41%` | `rate_limits.seven_day` | hidden |
| Directory | last part of `workspace.current_dir` | empty |

If the input is not valid JSON, the line reads `statusline error`.

## Memory and speed compared with other status lines

Measured on 2026-11-18 on an Apple M4 Pro with 24 GB of memory and 11 GB of transcripts. Every tool got the same stdin JSON pointing at a 179 MB transcript; N copies were started at once with different session IDs to simulate N windows refreshing together. Figures are the sum of each process's peak memory (`/usr/bin/time -l`), default settings.

| Tool | 1 window | 3 windows | 6 windows | Time for 6 windows |
|---|---|---|---|---|
| this script | 2 MB | 7 MB | 15 MB | about 0.1 s |
| [claude-pace](https://github.com/Astro-Han/claude-pace) | 7 MB | 20 MB | 41 MB | about 0.1 s |
| [ccstatusline](https://github.com/sirmalloc/ccstatusline) 2.2.34 | 200 MB | 586 MB | 1,217 MB | 0.5 s |
| [ccusage](https://github.com/ccusage/ccusage) 20.0.51 `statusline` | 2,502 MB | 4,015 MB | 7,995 MB | 20.5 s |

Method, caveats and the full write-up: [Which Claude Code status line uses the least memory?](https://kelvinwang.info/en/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=claude-code-statusline-lite) ([中文版](https://kelvinwang.info/zh-hant/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=claude-code-statusline-lite))

## When to use something else

- **You want to know whether you will run out before the reset.** [claude-pace](https://github.com/Astro-Han/claude-pace) is also stdin-only and compares usage with elapsed time in each window, and shows git status. It costs a few more MB.
- **You want many widgets, colours and an interactive layout editor.** [ccstatusline](https://github.com/sirmalloc/ccstatusline). Some widgets read the current session's transcript, so memory grows with long sessions.
- **You want today's total across every window, or weekly reports.** That number is not on stdin; it needs a scan of all transcripts. Run [ccusage](https://github.com/ccusage/ccusage) by hand when you want it (`ccusage claude daily`) instead of putting it in the status line.

## Customise

The output is a list joined by ` | `. Delete a line inside the `[ ... ]` block to drop a field, or add one using any field from the [stdin schema](https://code.claude.com/docs/en/statusline), for example:

```jq
("+" + (.cost.total_lines_added // 0 | tostring) + " -" + (.cost.total_lines_removed // 0 | tostring)),
```

To colour the whole line, pipe the output through `sed`, for example `| sed 's/^/\x1b[97m/;s/$/\x1b[0m/'` for bright white.

## Test

```sh
./test.sh
```

Runs the script on the inputs in `examples/` plus an empty object and invalid JSON, and compares the output. Tested on macOS with jq 1.7.1.

## Limitations

- The cost is this session only, as reported by Claude Code. There is no all-sessions or daily total.
- The 5h/7d limits appear only on plans that send `rate_limits`, and only after the first reply in a session.
- POSIX `sh` + `jq`; on Windows use WSL or Git Bash.

## License

MIT
