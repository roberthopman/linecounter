# q.rb

`q.rb` lists Ruby files with lines of code, churn, branching, and avg loc per item.

## Usage

```bash
ruby q.rb [options]
```

## Options

- `--top N` Show top N rows (default: 20).
- `--since STR` Limit churn to commits since date. Supports git-parseable dates in `YYYY-MM-DD` (e.g., `2025-01-01`), other git-parseable strings (e.g., `last friday`), and relative forms: `N.days.ago`, `N.weeks.ago`, `N.hours.ago`, `N.months.ago`, `N.years.ago`, plus `today`/`yesterday`.
- `--min-loc N` Exclude files below N non-empty lines (default: 20).
- `--repo PATH` Path to a git repo to scan (required).
- `--json` Output JSON instead of text.
- `--show-branch-count` Show per-branch keyword breakdown under each file.
- `--show-structure-overview` Show a summary of class structure counts across all files, including `avg_loc_per_item` (avg statement lines per item).
- `--show-interaction-overview` Alias for `--show-structure-overview`.
- `--detailed-structure` Show overall structure averages (avg lines per item) for each regex item across all files.
- `-h`, `--help` Show help.

## Examples

`--repo` is required. If omitted, the script prints only the `--repo` requirement line and exits.

```bash
ruby q.rb --repo /path/to/repo
ruby q.rb --repo /path/to/repo --top 50
ruby q.rb --repo /path/to/repo --since 2025-01-01
ruby q.rb --repo /path/to/repo --since 2.weeks.ago
ruby q.rb --repo /path/to/repo --min-loc 50
ruby q.rb --repo /path/to/repo --show-branch-count
ruby q.rb --repo /path/to/repo --show-structure-overview
ruby q.rb --repo /path/to/repo --detailed-structure
ruby q.rb --repo /path/to/repo --json
ruby q.rb --repo /path/to/repo --top 30 --since 3.months.ago --show-structure-overview
```
