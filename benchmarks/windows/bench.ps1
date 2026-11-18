# Windows status line comparison (see benchmarks/windows/README.md for the folder layout).
# Each status line command is written to a one-line wrapper file and run by Git Bash, with
# N windows started together. Memory is sampled every 15 ms. Writes cc-bench\runs.csv.
$ErrorActionPreference = "Stop"
$B = "$env:USERPROFILE\cc-bench"
$bash = "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
$fwd = { param($p) $p -replace '\\', '/' }
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
$env:CLAUDE_CONFIG_DIR = "$B\config"
$env:CLAUDE_COST_DIR = "$B\costcache"
$repo = & $fwd "$env:USERPROFILE\cc-usage-lite"
$b2 = & $fwd $B

# Sanity check: ccusage must actually read the synthetic history.
$daily = & "$B\ccusage\package\bin\ccusage.exe" claude daily --json --offline | ConvertFrom-Json
Write-Output ("ccusage sees input tokens: {0} (expected 19203100)" -f $daily.totals.inputTokens)

$tools = [ordered]@{
  "statusline.sh"       = "bash ""$repo/statusline.sh"""
  "statusline-today.sh" = "bash ""$repo/statusline-today.sh"""
  "claude-pace"         = "bash ""$b2/claude-pace.sh"""
  "ccstatusline 2.2.34" = """$b2/node-v22.23.5-win-x64/node.exe"" ""$b2/ccsl/node_modules/ccstatusline/dist/ccstatusline.js"""
  "ccusage 20.0.51"     = """$b2/ccusage/package/bin/ccusage.exe"" statusline --offline"
}
$names = @("bash", "sh", "jq", "awk", "gawk", "date", "mv", "mkdir", "cat", "sed", "git", "node", "ccusage", "rm", "rmdir", "stat")

# 40 cache files already recorded today for the daily variant, as on macOS.
$day = Get-Date -Format "yyyy-MM-dd"
New-Item -ItemType Directory -Force "$B\costcache\$day" | Out-Null
foreach ($k in 1..40) { [IO.File]::WriteAllText("$B\costcache\$day\s$k", "0 $k 0`n") }

$run = 0
function Reset-Cache {
  Get-ChildItem "$B\costcache" -Recurse -File | Where-Object { $_.Name -notmatch '^s\d+$' } | Remove-Item -Force
}
function Measure-Case($name, $cmd, $n) {
  Reset-Cache
  $script:run++
  $procs = @()
  $t0 = Get-Date
  for ($i = 0; $i -lt $n; $i++) {
    $sid = "win-$script:run-$i"
    $tp = & $fwd "$B\config\projects\benchmark\bench-$i.jsonl"
    $json = @{ session_id = $sid; transcript_path = $tp; cwd = "C:/Users/Kelvin/my-app";
      model = @{ id = "claude-opus-5-5"; display_name = "Opus 5.5" };
      workspace = @{ current_dir = "C:/Users/Kelvin/my-app"; project_dir = "C:/Users/Kelvin/my-app" };
      version = "2.1.327"; exceeds_200k_tokens = $false;
      cost = @{ total_cost_usd = 3.14; total_duration_ms = 600000; total_api_duration_ms = 200000; total_lines_added = 10; total_lines_removed = 2 };
      context_window = @{ context_window_size = 200000; used_percentage = 42.7; remaining_percentage = 57.3; total_input_tokens = 85000; total_output_tokens = 4000;
        current_usage = @{ input_tokens = 100; output_tokens = 400; cache_creation_input_tokens = 5000; cache_read_input_tokens = 80000 } };
      rate_limits = @{ five_hour = @{ used_percentage = 23.5; resets_at = 1795010400 }; seven_day = @{ used_percentage = 41.2; resets_at = 1795400000 } } } | ConvertTo-Json -Compress -Depth 5
    $in = "$B\in-$i.json"
    [IO.File]::WriteAllText($in, $json)
    $wrap = "$B\wrap-$script:run.sh"
    [IO.File]::WriteAllText($wrap, $cmd + "`n")
    $procs += Start-Process -FilePath $bash -ArgumentList @((& $fwd $wrap)) -RedirectStandardInput $in `
      -RedirectStandardOutput "$B\out-$i.txt" -RedirectStandardError "$B\err-$i.txt" -NoNewWindow -PassThru
  }
  $peak = 0
  while (($procs | Where-Object { -not $_.HasExited }).Count -gt 0) {
    $sum = (Get-Process -Name $names -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -ge $t0 } |
      Measure-Object WorkingSet64 -Sum).Sum
    if ($sum -gt $peak) { $peak = $sum }
    Start-Sleep -Milliseconds 15
  }
  $wall = ((Get-Date) - $t0).TotalSeconds
  $out = (Get-Content -Raw "$B\out-0.txt" -ErrorAction SilentlyContinue)
  return [pscustomobject]@{ tool = $name; windows = $n; wall = $wall; peakMB = $peak / 1MB; out = "$out".Trim() }
}

$rounds = 10
$csv = "$B\runs.csv"
[IO.File]::WriteAllText($csv, "round,tool,windows,wall_s,peak_mb`n")
foreach ($r in 1..$rounds) {
  foreach ($t in $tools.GetEnumerator()) {
    foreach ($n in 1, 3, 6) {
      $x = Measure-Case $t.Key $t.Value $n
      $line = "{0},{1},{2},{3:F3},{4:F1}" -f $r, $x.tool, $x.windows, $x.wall, $x.peakMB
      [IO.File]::AppendAllText($csv, $line + "`n")
      Write-Output $line
      if ($r -eq 1 -and $n -eq 1) { $o = ($x.out -replace '\x1b\[[0-9;]*m', '') -replace '\x1b', ''; Write-Output ("    output: " + $o.Substring(0, [Math]::Min(150, $o.Length))) }
    }
  }
}
