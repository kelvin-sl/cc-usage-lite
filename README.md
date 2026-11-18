# cc-usage-lite

[![test](https://github.com/kelvin-sl/cc-usage-lite/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kelvin-sl/cc-usage-lite/actions/workflows/test.yml)
![shell](https://img.shields.io/badge/shell-POSIX%20sh-89e051)
![jq](https://img.shields.io/badge/jq-%E2%89%A51.6-blue)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**A lightweight status line for Claude Code. Replace `ccusage statusline`; keep ccusage for reports.**

See your model, context usage, session cost and available rate limits at a glance.
One shell script and one `jq` call per refresh, using the data Claude Code already provides.

[Quick start](#quick-start) · [Why cc-usage-lite?](#why-cc-usage-lite) ·
[Benchmark](#benchmark) · [Documentation](#documentation)

## See it in action

Sample output from the [subscription fixture](examples/subscription.json), with `TZ=UTC`:

```text
Opus 5.5 | ctx 42% | $3.14 | 5h 23% (14:00) | 7d 41% | my-app
```

The line shows the model, context used, session cost estimate, five-hour and seven-day
rate-limit usage, and project directory. Reset times use your local timezone. Rate-limit
fields appear only when Claude Code supplies them. Session cost is an estimate, not your
subscription bill.

## Why cc-usage-lite?

- **Small by design.** The main script formats stdin with a single `jq` call. It does not
  scan transcripts, so its work does not grow with conversation history.
- **Local and stateless.** The main script makes no network requests, writes no files and
  starts no background service. No Node.js or Bun runtime is needed for the status line.
- **Easy to adopt.** Change Claude Code's status line command. Keep your transcripts,
  ccusage installation and historical reports; no data migration is needed.
- **Easy to inspect.** Read the [main script](statusline.sh), or customize the
  [displayed fields](docs/reference.md). It needs a POSIX shell and jq 1.6+.

### How it fits alongside ccusage

| Need | cc-usage-lite | ccusage |
| :--- | :------------ | :------ |
| Model, context and session cost in the status line | Reads Claude Code stdin | Available in its status line |
| 5h / 7d rate-limit usage | Displays it when Claude Code supplies it | Billing-block estimates are a different metric |
| Daily and historical usage reports | Keep ccusage for these | Transcript-based reports |
| Optional daily number in the status line | [Observed estimate, beta](docs/daily-estimate.md) | Transcript-based daily/block totals |

Choose the main script when you want a small status line and use reports separately.
The optional `today` estimate omits unobserved usage and can assign midnight-spanning work
imprecisely; it is not equivalent to ccusage's daily total. Git widgets, themes and pace
calculations are outside this project's scope.

## Benchmark

A reproducible **same-machine macOS ARM64 sample**, recorded on 2026-11-18: 32 MiB of
synthetic transcripts across 40 sessions, 3 repetitions, jq 1.7.1-apple and ccusage 20.0.51.
Each time is the median wall time until all commands in the batch finish.

| Tool / cache condition | 1-window batch | 6-window batch | Per-invocation peak RSS, 6-window runs |
| :--------------------- | -------------: | -------------: | -----------------------------------: |
| `statusline.sh` | 10 ms | 21 ms | 2.16 MiB |
| `statusline-today.sh` | 23 ms | 30 ms | 2.31 MiB |
| ccusage, cache disabled | 162 ms | 333 ms | 78.41 MiB |
| ccusage, primed with unchanged input | 42 ms | 146 ms | 46.97 MiB |

These commands provide different features: ccusage also computes historical daily/block
information. The sample measures their respective costs, not equivalent functionality.
Priming uses a one-hour cache interval, not ccusage's default. Batch time includes harness
and launch overhead; RSS is the per-invocation value reported by `/usr/bin/time`, not total
memory across six windows or a whole process tree. Three repetitions on synthetic data do
not establish performance for every workload, machine or OS.

[Raw samples, commands and source hashes](benchmarks/results/2026-11-18-macos-arm64.json) ·
[Methodology and reproduction](benchmarks/README.md)

<a id="windows-comparison-with-other-status-lines"></a>

Windows exploratory measurements are [archived separately](benchmarks/windows/README.md).
They still need validation before use as comparative evidence; this table makes no
Windows-versus-macOS performance claim.

## Platform support

| Environment | Requirements | Automated coverage |
| :---------- | :----------- | :----------------- |
| macOS | POSIX shell, jq 1.6+ | Script tests and benchmark smoke test |
| Linux | POSIX shell, jq 1.6+ | Script tests, including jq 1.6 with dash, and benchmark smoke test |
| Native Windows | Git Bash, jq 1.6+ | Script tests, benchmark smoke test, installer checks in PowerShell 5.1 and 7 |
| WSL | Claude Code and dependencies inside the same distribution | No dedicated WSL integration test |

CI verifies scripts and installer behavior; it does not launch interactive Claude Code
sessions on every platform. See the [environment guide](docs/getting-started.md#1-check-your-environment)
for setup and live verification.

## Quick start

<a id="1-check-your-environment"></a>
<a id="2-download-and-preview"></a>
<a id="3-configure-claude-code"></a>

For macOS, Linux, WSL or Git Bash, with Claude Code, `curl` and jq 1.6+ installed:

```sh
mkdir -p "$HOME/.claude"
curl -fsSL https://raw.githubusercontent.com/kelvin-sl/cc-usage-lite/main/statusline.sh -o "$HOME/.claude/cc-usage-lite.sh"
```

In `~/.claude/settings.json`, add the following object if no status line exists. If you
already have settings, [back them up](docs/getting-started.md#back-up-settings) and merge
only this field; for an existing status line, replace only its `command` value.

```json
{
  "statusLine": {
    "type": "command",
    "command": "sh \"$HOME/.claude/cc-usage-lite.sh\""
  }
}
```

Send a message in a trusted Claude Code project and check the line after the reply.
For a custom `CLAUDE_CONFIG_DIR`, use that directory and adjust the command path. The
[full guide](docs/getting-started.md) includes dependency installation, a preview and troubleshooting.

<a id="windows-one-command"></a>

**Native Windows:** from a downloaded or cloned checkout, run in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer finds Git Bash and configures the status line, with backups. See the
[Windows instructions](docs/getting-started.md#windows-one-command) for prerequisites and verification.

## Documentation

<a id="start-from-zero"></a>
<a id="switch-from-ccusage"></a>
<a id="switch-from-another-status-line"></a>
<a id="back-up-settings"></a>
<a id="restore-or-uninstall"></a>
<a id="optional-observed-daily-estimate"></a>
<a id="compare-with-ccusage"></a>
<a id="fields-and-customization"></a>

| Guide | What you will find |
| :---- | :----------------- |
| [Start from zero](docs/getting-started.md) | Dependencies, installation, preview and live checks |
| [Switch from ccusage](docs/migrate-from-ccusage.md) | Replace the status line, keep reports, understand changed fields |
| [Switch from another status line](docs/migrate-from-other-statuslines.md) | Preserve your old setup and check feature differences |
| [Back up and restore](docs/getting-started.md#back-up-settings) | Save settings, restore a previous command or uninstall |
| [Observed daily estimate](docs/daily-estimate.md) | Beta setup, baselines, midnight behavior and comparison with ccusage |
| [Fields and customization](docs/reference.md) | Data sources, missing values and display changes |
| [Benchmark methodology](benchmarks/README.md) | Reproduce the sample and interpret its limits |

## Scope and alternatives

For historical reports, use [ccusage](https://github.com/ccusage/ccusage). For pace guidance,
see [claude-pace](https://github.com/Astro-Han/claude-pace); for configurable widgets and
layouts, see [ccstatusline](https://github.com/sirmalloc/ccstatusline).

Background write-up: [Which Claude Code status line uses the least memory?](https://kelvinwang.info/en/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=cc-usage-lite)
([中文版](https://kelvinwang.info/zh-hant/blog/claude-code-statusline-memory/?utm_source=github&utm_medium=readme&utm_campaign=cc-usage-lite)).
Use the [benchmark methodology and raw samples](benchmarks/README.md) for measurement details.

## Verification and contributing

```sh
./test.sh
python3 -m unittest discover -s benchmarks -p 'test_*.py'
```

Tests cover formatting, cost accumulation, baselines, approximate midnight assignment,
counter resets, invalid input, retention, concurrent distinct sessions and comparison-command
failures. The Python benchmark checks synthetic token counts against ccusage before timing.

[Bug reports](https://github.com/kelvin-sl/cc-usage-lite/issues) and small fixes are welcome.
Include your OS, shell, jq version, expected output and sanitized sample stdin. Add a test
for changed behavior. If this tool helps your workflow, a GitHub star helps others find it.

## Security and updates

The main script reads stdin and writes nothing. The optional daily script writes a dedicated
cache; see its [behavior and limits](docs/daily-estimate.md). Neither script opens transcripts
or makes network calls. Report vulnerabilities through a
[private advisory](https://github.com/kelvin-sl/cc-usage-lite/security/advisories/new).

Downloads follow `main`. Replace `main` in the URL with a reviewed full commit SHA to pin
it. Save customized scripts before updating; beta output may evolve. No automatic updater
is installed.

## License

[MIT](LICENSE).
