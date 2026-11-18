# Switch from ccusage

You can keep ccusage installed for `ccusage claude daily`, weekly and monthly reports.
Only replace its status line command.

On native Windows, you can instead use the [PowerShell installer](getting-started.md#windows-one-command),
then verify the live output and review the feature changes below. The installer backs up
your settings and script before replacing the status line.

1. [Back up your settings](getting-started.md#back-up-settings).
2. Follow [Download and preview](getting-started.md#2-download-and-preview).
3. Find the existing `statusLine` object in your active settings. Replace its `command`
   (`npx -y ccusage statusline`, `bun x ccusage statusline`, a wrapper, etc.) with
   `sh "$HOME/.claude/cc-usage-lite.sh"`, escaped as shown in the
   [configuration example](getting-started.md#3-configure-claude-code). Keep unrelated
   settings and optional layout fields such as `padding`.
4. Send a message and verify the live line. To go back, restore the saved `statusLine` object.

| After switching to the main script | What changes |
| :-------------------------------- | :----------- |
| Model, context percentage, session cost | Read directly from Claude Code stdin |
| 5-hour / 7-day rate-limit percentages | Shown when supplied by Claude Code; these are not ccusage's billing-block estimates |
| Today's transcript total, block cost, burn rate | Not provided; use ccusage reports or the optional observed estimate |
| Historical reports and existing transcripts | Remain available to ccusage; no data migration or deletion |

Do not expect the optional `today` number to match ccusage: the two tools observe and price
different data. See [the estimate's limits](daily-estimate.md).

[Restore your previous setup](getting-started.md#restore-or-uninstall) · [Back to the project](../README.md)
