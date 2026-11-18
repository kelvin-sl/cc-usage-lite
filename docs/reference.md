# Fields and customization

| Field | Source | Missing value |
| :---- | :----- | :------------ |
| Model | `model.display_name` | `?` |
| Context | `context_window.used_percentage` | `ctx -` |
| Session cost | `cost.total_cost_usd` | `$0` |
| 5h usage and local reset time | `rate_limits.five_hour` | Hidden |
| 7d usage | `rate_limits.seven_day` | Hidden |
| Directory | `workspace.current_dir`, then `cwd` | Empty |

Invalid JSON prints `statusline error`. Remove a field from the script's `[ ... ]` list to
hide it. Other available values are documented in the
[Claude Code stdin schema](https://code.claude.com/docs/en/statusline#available-data).

[Daily estimate behavior](daily-estimate.md) · [Back to the project](../README.md)
