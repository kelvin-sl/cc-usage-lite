# Start from zero

## 1. Check your environment

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

### Windows: one command

On native Windows (Claude Code with Git Bash), download or clone this repository, open
PowerShell in its folder and run the installer below. After it succeeds, skip steps 2 and 3 and verify the status line
in a new Claude Code window:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Add `-Today` to install the [observed daily estimate](daily-estimate.md) instead.
The installer finds Git Bash, installs jq if it is missing (winget, or a download into
`%USERPROFILE%\.claude\bin`), copies the script to `%USERPROFILE%\.claude\statusline.sh`,
sets `statusLine` in `settings.json` to `bash "C:/Users/<you>/.claude/statusline.sh"` while keeping
your other settings, backs up both files as `*.bak-<timestamp>`, and runs the command once on
sample input. Open a new Claude Code window afterwards. CI runs the installer in Windows
PowerShell and PowerShell 7 and checks that existing settings survive.

## 2. Download and preview

These commands use the default `~/.claude` directory. If you use a custom `CLAUDE_CONFIG_DIR`,
use that directory for both the script and settings, and adjust the command accordingly.

```sh
mkdir -p "$HOME/.claude"
curl -fsSL https://raw.githubusercontent.com/kelvin-sl/cc-usage-lite/main/statusline.sh -o "$HOME/.claude/cc-usage-lite.sh"
chmod +x "$HOME/.claude/cc-usage-lite.sh"
printf '%s\n' '{"model":{"display_name":"Preview"},"context_window":{"used_percentage":42},"cost":{"total_cost_usd":3.14},"workspace":{"current_dir":"/projects/my-app"}}' | sh "$HOME/.claude/cc-usage-lite.sh"
```

Expected preview:

```text
Preview | ctx 42% | $3.14 | my-app
```

The dedicated filename leaves an existing `statusline.sh` alone. Downloading again updates
`cc-usage-lite.sh`; save a copy first if you customized that file.

## 3. Configure Claude Code

If `~/.claude/settings.json` does **not** exist, create it with this complete JSON:

```json
{
  "statusLine": {
    "type": "command",
    "command": "sh \"$HOME/.claude/cc-usage-lite.sh\""
  }
}
```

If it already exists, [back it up](#back-up-settings), then edit only the `statusLine.command` value (or add a `statusLine` object if absent). Keep
existing layout options such as `padding`.
Preserve your other settings and keep the file valid JSON. You can check it with:

```sh
jq empty "$HOME/.claude/settings.json"
```

Claude Code picks up a changed status line command without a restart. Send a message in a
trusted project and check the line after the reply. `ctx -` can appear before usage is
available; rate-limit fields are hidden when Claude Code does not provide them.

If it stays blank, run the preview again and check the configured path, jq availability,
and any project or managed settings overriding your user configuration.

## Back up settings

In macOS/Linux/WSL or Git Bash, this creates a uniquely named copy and prints its path:

```sh
backup=$(mktemp "$HOME/.claude/settings.json.before-cc-usage-lite.XXXXXX") &&
  cp -p "$HOME/.claude/settings.json" "$backup" &&
  printf 'Settings backup: %s\n' "$backup"
```

Run this only when the settings file exists. Save the printed path; it also preserves
any custom status line options you may want to restore later.

## Restore or uninstall

- **Previously used another status line:** copy the `statusLine` object from your saved
  settings back into the active file. Restore the whole backup only if you have made no
  other settings changes since taking it.
- **Started without a status line:** remove just the `statusLine` field from settings.
- After switching the command away, you may remove `~/.claude/cc-usage-lite.sh`
  (or `%USERPROFILE%\.claude\statusline.sh` for the Windows installer).
  The optional daily cache can be left in place or removed separately after checking its path;
  it is not automatically cleaned once the daily script stops running.

The Windows installer creates timestamped backups beside the original script and settings.
To restore, copy the saved `statusLine` object into your current settings; restore the
script backup too if the installer replaced an existing `statusline.sh`.

[Back to the project](../README.md)
