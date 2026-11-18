# Reproduce the status line benchmark

Requires Python 3.10+, jq 1.6+ and `sh`. The installed status line does not need Python.
Use an already-installed ccusage to include it; the benchmark does not install packages.

```sh
# Default: 1 and 32 MiB histories, 40 sessions, 1 and 6 windows, 3 repetitions.
python3 benchmarks/benchmark.py --ccusage --output /tmp/cc-usage-benchmark.json

# Larger history; choose sizes your machine can comfortably hold.
python3 benchmarks/benchmark.py --ccusage --history-mib 1 32 256 --windows 1 3 6 --repeats 5 --output /tmp/cc-usage-benchmark-large.json

# Smoke test without ccusage. Use `python` if that is your Python 3 command in Git Bash.
python3 benchmarks/benchmark.py --history-mib 1 --windows 1 2 --sessions 2 --repeats 1 --output /tmp/cc-usage-benchmark-smoke.json
```

Output files must not already exist. Do not commit your own machine's results without
reviewing them: raw commands contain installation paths, though transcripts are synthetic.
The sample checked into `results/` contains no real conversation data.

## Workload and isolation

- A temporary Claude config contains `projects/benchmark/bench-N.jsonl` files. Each message
  has a unique request/message ID, 100 input tokens, 20 output tokens and 1 KiB synthetic text.
  These are controlled byte-heavy transcripts, not a representative distribution of real turns.
- All messages are dated at generation time, in the canonical millisecond UTC format.
  Files are split across `--sessions`; actual byte counts and message counts are recorded.
- `CLAUDE_CONFIG_DIR` points exclusively at this generated history. `CLAUDE_COST_DIR`,
  `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` and temporary-directory variables point into the temporary
  workspace. ccusage receives an explicit empty config and `--offline`; no real transcripts
  are selected and the harness never changes your Claude settings.
- Before timing ccusage, the harness runs `ccusage claude daily --json --offline` and verifies
  its total input-token count against the number generated. An empty or ignored fixture
  aborts the run instead of producing a misleading fast result.
- Each window has its own session ID and transcript path. The input is otherwise the same
  for each tool, and the daily variant starts with `--sessions` small cache files.
- Versions, exact commands, stdin payloads, source SHA-256 hashes, stdout, stderr and the
  unmodified `/usr/bin/time` output are saved in JSON. Temporary datasets are removed on exit.

## Cache conditions

`ccusage-no-cache` explicitly uses `--no-cache`; it measures repeated transcript work.
`ccusage-primed-unchanged` runs the same inputs before each measured batch, then uses
`--cache --refresh-interval 3600`. Priming is not timed. This favors reuse and is **not**
ccusage's default one-second interval. The name describes the setup, not a verified cache hit:
cache behavior can change between versions.

OS filesystem caches are not flushed, so neither condition is a cold-disk benchmark.
The fixed order and small repeat count are useful for local comparison, not a claim of
statistical significance. There is no changing-transcript or long-running interactive workload.

## Reading the metrics

- **Batch seconds:** wall time to run N commands together, including Python thread scheduling,
  process creation and the timing wrapper. The printed value is the median across repetitions.
- **Per-invocation peak RSS:** the value reported by `/usr/bin/time -l` on macOS or
  `/usr/bin/time -v` on Linux, converted from bytes or KiB to MiB respectively. The printed
  value is the median across individual invocations in all repetitions.
- This RSS metric is **not** a sampled sum of all processes alive at the same instant. It
  must not be multiplied by the number of windows or described as total resident memory
  for an entire process tree. Launchers, child processes and OS accounting differ.
- Windows records wall time and leaves RSS `null`; there is no equivalent memory comparison
  from this harness on Windows. Compare tools on the same machine and OS.
- Nonzero exits, empty output, `statusline error`, timeouts or unparseable timing data abort
  the run. A failed tool is never represented as a successful zero-cost sample.

The commands provide different features. ccusage reports historical daily/block information;
the minimal script only formats data already supplied on stdin. Performance alone does not
make one a complete replacement for the other.

## Tests

```sh
python3 -m unittest discover -s benchmarks -p 'test_*.py'
```

CI checks fixture generation, memory-unit parsing, command failures and an actual small
benchmark of the two local scripts on macOS, Linux and Windows Git Bash. It does not install
ccusage or claim an interactive Claude Code integration test.
