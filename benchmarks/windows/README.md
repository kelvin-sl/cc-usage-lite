# Windows comparison benchmark

`bench.ps1` compares five status line commands on native Windows, run through Git Bash as
Claude Code does when Git for Windows is installed. Unlike `benchmarks/benchmark.py`, it
samples the **sum of WorkingSet for selected process names**, not per-process RSS.
The two sets of numbers are different metrics and must not be compared with each other.

Raw data from the run below: [`../results/2026-11-18-windows-x64.csv`](../results/2026-11-18-windows-x64.csv),
one row per run (`round,tool,windows,wall_s,peak_mb`); time and memory in a row come from the same run.

## Validation status

These are exploratory measurements, retained with their raw data for review. They are not
validated comparative evidence and must not be used to infer Windows-versus-macOS performance.

The current harness does not reject nonzero tool exits or assert the printed input-token
count. It samples processes by name and start time rather than verified process ancestry,
and starts sampling only after all launch requests. It can miss startup peaks or include
unrelated processes. The 15 ms sleep is in addition to process-enumeration time; it is not
a guaranteed sampling interval. Launches are sequential requests without a start barrier.
ccusage cache conditions are not explicitly matched to the macOS run.

Before promoting results, add failure/output checks, isolate measured processes, define the
sampling and launch timing, and rerun with explicit cache conditions. This status concerns
the benchmark harness, not evidence of a defect in any measured status line.

## Run of 2026-11-18

- Windows 10 (NT 10.0.19045), AMD Ryzen 5 5600X (12 logical processors), Windows PowerShell 5.1
- Git for Windows 2.56.1, jq 1.7.1, cc-usage-lite at commit `80b7df1`
- claude-pace: single `claude-pace.sh`, SHA-256 `F92039FCBCEF1777A71681C681E940E2833DD90ABAFBDC3223EAE7D76C07EBCA`
- ccstatusline 2.2.34 on portable Node.js 22.23.5
- ccusage 20.0.51, native binary from `@ccusage/ccusage-win32-x64`, run as `ccusage statusline --offline`
- History: 268,468,650 bytes in 40 session files from `make_history(config, 256, 40)` in
  `benchmarks/benchmark.py` (synthetic, no real conversations). Before timing, the script prints
  the `ccusage claude daily` input-token count alongside the expected 19,203,100;
  the saved run matched, but the script does not enforce equality.

## Method

- 10 rounds. In each round every tool runs with 1, 3 and 6 windows, tools interleaved, so
  slow drift of the machine affects all tools alike. 150 runs in total.
- A run requests N `bash.exe` processes in succession, each with its own `session_id` and stdin JSON.
  Wall time includes JSON/wrapper preparation, process launches and exit polling.
- Memory: after requesting all launches, each sampling loop sleeps 15 ms; the WorkingSet of
  processes named bash, sh, jq, awk, gawk, date, mv,
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

## Archived exploratory summary

Medians of 10 runs, with minimum and maximum in brackets. The `MB` labels below reproduce
the original table; the script divides bytes by 1,048,576, so the values are in MiB.
Read the validation status above before interpreting these numbers.

| Tool | 1 window | 3 windows | 6 windows |
| :--- | :------- | :-------- | :-------- |
| `statusline.sh` | 0.11 s [0.11–0.14]<br>27 MB [22–30] | 0.14 s [0.13–0.16]<br>70 MB [60–90] | 0.20 s [0.18–0.22]<br>105 MB [74–125] |
| `statusline-today.sh` | 0.23 s [0.23–0.24]<br>40 MB [30–42] | 0.28 s [0.26–0.30]<br>100 MB [88–107] | 0.38 s [0.34–0.42]<br>197 MB [171–217] |
| claude-pace | 0.36 s [0.35–0.38]<br>44 MB [38–50] | 0.39 s [0.37–0.41]<br>111 MB [106–148] | 0.51 s [0.48–0.53]<br>219 MB [176–245] |
| ccstatusline 2.2.34 | 0.36 s [0.35–0.38]<br>90 MB [88–95] | 0.40 s [0.39–0.41]<br>272 MB [265–279] | 0.55 s [0.52–0.56]<br>510 MB [493–526] |
| ccusage 20.0.51 | 1.75 s [1.70–1.79]<br>206 MB [199–252] | 2.73 s [2.71–2.83]<br>572 MB [542–601] | 4.45 s [4.41–4.57]<br>1,059 MB [1,012–1,078] |
