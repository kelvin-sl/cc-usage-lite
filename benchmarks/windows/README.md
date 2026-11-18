# Windows comparison benchmark

`bench.ps1` compares five status line commands on native Windows, run through Git Bash as
Claude Code does when Git for Windows is installed. Unlike `benchmarks/benchmark.py`, it
measures the **sum of all processes alive at the same time** (sampled), not per-process RSS.
The two sets of numbers are different metrics and must not be compared with each other.

Raw data from the run below: [`../results/2026-11-18-windows-x64.csv`](../results/2026-11-18-windows-x64.csv),
one row per run (`round,tool,windows,wall_s,peak_mb`); time and memory in a row come from the same run.

## Run of 2026-11-18

- Windows 10 (NT 10.0.19045), AMD Ryzen 5 5600X (12 logical processors), Windows PowerShell 5.1
- Git for Windows 2.56.1, jq 1.7.1, cc-usage-lite at commit `80b7df1`
- claude-pace: single `claude-pace.sh`, SHA-256 `F92039FCBCEF1777A71681C681E940E2833DD90ABAFBDC3223EAE7D76C07EBCA`
- ccstatusline 2.2.34 on portable Node.js 22.23.5
- ccusage 20.0.51, native binary from `@ccusage/ccusage-win32-x64`, run as `ccusage statusline --offline`
- History: 268,468,650 bytes in 40 session files from `make_history(config, 256, 40)` in
  `benchmarks/benchmark.py` (synthetic, no real conversations). Before timing, the script checks
  that `ccusage claude daily` reads 19,203,100 input tokens, the generated count.

## Method

- 10 rounds. In each round every tool runs with 1, 3 and 6 windows, tools interleaved, so
  slow drift of the machine affects all tools alike. 150 runs in total.
- A run starts N `bash.exe` processes together, each with its own `session_id` and stdin JSON.
  Wall time is from the first start until the last process exits.
- Memory: every 15 ms, the WorkingSet of processes named bash, sh, jq, awk, gawk, date, mv,
  mkdir, cat, sed, git, node, ccusage, rm, rmdir or stat that started after the run began is
  summed; the highest sum is reported. Short-lived processes between samples are missed, so
  values may be low. WorkingSet includes shared DLLs, so every Git Bash process counts the
  msys runtime again.
- Before every run the daily cache is reset to 40 seeded files, so `statusline-today.sh`
  shows `today $820.00` from those files, not from real spending.

## Folder layout

The script expects `%USERPROFILE%\cc-usage-lite` (this repo) and `%USERPROFILE%\cc-bench` with:

```text
cc-bench\config\projects\benchmark\bench-*.jsonl     generated history
cc-bench\claude-pace.sh
cc-bench\node-v22.23.5-win-x64\node.exe
cc-bench\ccsl\node_modules\ccstatusline\              npm install ccstatusline@2.2.34
cc-bench\ccusage\package\bin\ccusage.exe              npm pack @ccusage/ccusage-win32-x64@20.0.51, extracted
```

Git for Windows is expected per-user in `%LOCALAPPDATA%\Programs\Git`; edit `$bash` otherwise.
Run with `powershell -ExecutionPolicy Bypass -File benchmarks\windows\bench.ps1`.
ccstatusline creates `%USERPROFILE%\.config\ccstatusline` on first run; delete it afterwards
if you do not use ccstatusline.
