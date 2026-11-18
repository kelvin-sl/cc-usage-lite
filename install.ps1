# cc-usage-lite installer for native Windows (Claude Code with Git Bash).
#
# From the repo folder, in PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1            # statusline.sh
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Today     # statusline-today.sh
#
# What it does:
#   1. Finds Git Bash (CLAUDE_CODE_GIT_BASH_PATH, then git on PATH, then the usual folders).
#   2. Makes sure jq is available (winget, or a download into %USERPROFILE%\.claude\bin).
#   3. Copies the script to %USERPROFILE%\.claude\statusline.sh with LF line endings.
#   4. Sets "statusLine" in %USERPROFILE%\.claude\settings.json, keeping every other setting.
#      Existing files are backed up next to themselves as *.bak-<timestamp>.
#   5. Runs the installed command once on sample input and prints the result.
param(
  [switch]$Today,
  [string]$ClaudeDir = (Join-Path $env:USERPROFILE ".claude")
)
$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Fwd($path) { return ($path -replace '\\', '/') }

# 1. Git Bash
Step "Looking for Git Bash"
$candidates = @()
if ($env:CLAUDE_CODE_GIT_BASH_PATH) { $candidates += $env:CLAUDE_CODE_GIT_BASH_PATH }
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
  $gitRoot = Split-Path (Split-Path $git.Source -Parent) -Parent
  $candidates += (Join-Path $gitRoot "bin\bash.exe")
}
$candidates += (Join-Path $env:ProgramFiles "Git\bin\bash.exe")
if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe") }
$bash = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $bash) { Fail "Git Bash not found. Install Git for Windows (winget install Git.Git) and run this again." }
Write-Host "    $bash"

# 2. jq
function Find-Jq {
  $out = & $bash -c "command -v jq >/dev/null 2>&1 && jq --version" 2>$null
  if ($LASTEXITCODE -eq 0 -and $out) { return $out }
  return $null
}
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
Step "Checking jq"
$jq = Find-Jq
if (-not $jq -and (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "    installing jq with winget"
  winget install --id jqlang.jq -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
  Refresh-Path
  $jq = Find-Jq
}
if (-not $jq) {
  Write-Host "    downloading jq into $ClaudeDir\bin"
  $binDir = Join-Path $ClaudeDir "bin"
  New-Item -ItemType Directory -Force -Path $binDir | Out-Null
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe" -OutFile (Join-Path $binDir "jq.exe")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (($userPath -split ';') -notcontains $binDir) {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $binDir), "User")
  }
  Refresh-Path
  $jq = Find-Jq
}
if (-not $jq) { Fail "jq is still not available to Git Bash. Install it (winget install jqlang.jq), open a new terminal and run this again." }
Write-Host "    $jq"

# 3. Script
$name = "statusline.sh"
if ($Today) { $name = "statusline-today.sh" }
$src = Join-Path $repo $name
if (-not (Test-Path $src)) { Fail "$src not found. Run this from the cc-usage-lite folder." }
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
$dest = Join-Path $ClaudeDir "statusline.sh"
Step "Installing $name as $dest"
if (Test-Path $dest) {
  Copy-Item $dest "$dest.bak-$stamp"
  Write-Host "    backup: $dest.bak-$stamp"
}
$text = [IO.File]::ReadAllText($src) -replace "`r`n", "`n"
[IO.File]::WriteAllText($dest, $text, $utf8)

# 4. settings.json
$settingsPath = Join-Path $ClaudeDir "settings.json"
# Claude Code runs status line commands through Git Bash when it is installed, and Git Bash
# needs forward slashes in paths (https://code.claude.com/docs/en/statusline#windows-configuration).
$command = 'bash "' + (Fwd $dest) + '"'
Step "Setting statusLine in $settingsPath"
$settings = New-Object PSObject
if (Test-Path $settingsPath) {
  $raw = [IO.File]::ReadAllText($settingsPath)
  if ($raw.Trim()) {
    try { $settings = $raw | ConvertFrom-Json } catch { Fail "$settingsPath is not valid JSON; fix it first. Nothing was changed." }
  }
  Copy-Item $settingsPath "$settingsPath.bak-$stamp"
  Write-Host "    backup: $settingsPath.bak-$stamp"
}
$statusLine = [ordered]@{ type = "command"; command = $command; padding = 0 }
if ($settings.PSObject.Properties.Name -contains "statusLine") {
  $settings.statusLine = $statusLine
} else {
  $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $statusLine
}
[IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 100), $utf8)
Write-Host "    command: $command"

# 5. Self-test with sample input (the today variant writes to a temporary folder here)
Step "Testing the installed command"
$sample = [IO.File]::ReadAllText((Join-Path $repo "examples\subscription.json"))
$testDir = Join-Path ([IO.Path]::GetTempPath()) "cc-usage-lite-test-$stamp"
$env:CLAUDE_COST_DIR = Fwd $testDir
$out = $sample | & $bash $dest
Remove-Item Env:\CLAUDE_COST_DIR
Remove-Item -Recurse -Force $testDir -ErrorAction SilentlyContinue
Write-Host "    $out"
if ("$out" -notmatch '^Opus 5\.5 \| ctx 42% \| \$3\.14 \|') { Fail "unexpected output from the status line" }

Write-Host ""
Write-Host "Done. Open a new Claude Code window to see the status line." -ForegroundColor Green
Write-Host "To undo: restore the .bak-$stamp files in $ClaudeDir, or remove ""statusLine"" from settings.json."
