# Switch from another status line

The same process applies to ccstatusline, claude-pace, custom scripts and other tools that
set Claude Code's `statusLine.command`.

On native Windows, the [PowerShell installer](getting-started.md#windows-one-command)
provides the installation and backup steps. If it replaces an existing `statusline.sh`,
keep that script backup as well as your settings backup for rollback.

1. [Back up your settings](getting-started.md#back-up-settings), including the complete old `statusLine` object.
2. [Download and preview](getting-started.md#2-download-and-preview) using the dedicated
   `cc-usage-lite.sh` filename.
3. Replace only the active `statusLine.command`, using the [configuration example](getting-started.md#3-configure-claude-code). Leave the old
   tool's executable, config files, plugins and any unrelated hooks in place.
4. Check the live output. Git widgets, themes, pace calculations and custom layouts from
   the old tool are not imported. Restore the old object if you prefer those features.

If a tool regenerates your settings, stop its status-line configuration step from overwriting
this command. Tools configured through other mechanisms need their own instructions; this
is a migration of Claude Code's status line setting, not a universal uninstaller.

[Restore your previous setup](getting-started.md#restore-or-uninstall) · [Back to the project](../README.md)
