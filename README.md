# linecounter

`linecounter` lists Ruby files with lines of code, churn, branching, and avg loc per item.

## Installation

Install the gem:

```bash
gem install linecounter
```

Or add it to a Gemfile:

```ruby
gem "linecounter"
```

From a checkout you can run it without installing:

```bash
ruby -Ilib exe/linecounter --repo /path/to/repo
```

## Usage

```bash
linecounter [options]
```

## Options

- `--top N` Show top N rows (default: 20).
- `--since STR` Limit churn to commits since date. Supports git-parseable dates in `YYYY-MM-DD` (e.g., `2025-01-01`), other git-parseable strings (e.g., `last friday`), and relative forms: `N.days.ago`, `N.weeks.ago`, `N.hours.ago`, `N.months.ago`, `N.years.ago`, plus `today`/`yesterday`.
- `--min-loc N` Exclude files below N non-empty lines (default: 20).
- `--repo PATH` Path to a git repo to scan (default: current directory).
- `--json` Output JSON instead of text.
- `--show-branch-count` Show per-branch keyword breakdown under each file.
- `--show-structure-overview` Show a summary of class structure counts across all files, including `avg_loc_per_item` (avg statement lines per item).
- `--show-interaction-overview` Alias for `--show-structure-overview`.
- `--detailed-structure` Show overall structure averages (avg lines per item) for each regex item across all files.
- `--crud-only-controllers` List Rails controllers (files matching `app/controllers/**/*_controller.rb`) whose public actions are all standard RESTful actions (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`). Private and protected methods are ignored; a single non-CRUD public action excludes the controller.
- `--non-crud-controllers` The inverse: list controllers that expose at least one custom (non-RESTful) public action, showing those extra actions. Useful for spotting controllers that have grown beyond plain resourceful routing.
- `--no-churn` Skip git churn computation. Churn runs one `git log` per file, so on large repos it dominates runtime; skipping it makes runs near-instant at the cost of a `0` Churn column. Useful with `--crud-only-controllers`, which does not need churn.
- `-h`, `--help` Show help.

## Examples

`--repo` defaults to the current directory, so running `linecounter` with no
arguments scans the repo you're in. If the directory isn't a git repository it
exits with an error.

```bash
linecounter
linecounter --repo /path/to/repo
linecounter --repo /path/to/repo --top 50
linecounter --repo /path/to/repo --since 2025-01-01
linecounter --repo /path/to/repo --since 2.weeks.ago
linecounter --repo /path/to/repo --min-loc 50
linecounter --repo /path/to/repo --show-branch-count
linecounter --repo /path/to/repo --show-structure-overview
linecounter --repo /path/to/repo --detailed-structure
linecounter --repo /path/to/repo --crud-only-controllers
linecounter --repo /path/to/repo --non-crud-controllers --no-churn
linecounter --repo /path/to/repo --json
linecounter --repo /path/to/repo --top 30 --since 3.months.ago --show-structure-overview
```

## Example Output

Signals are computed from the parsed AST (via [Prism](https://github.com/ruby/prism)),
so keywords in strings or comments are never miscounted and `avg_loc_per_item`
reflects real definition length. Churn varies with git history, so your numbers
will differ:

```bash
$ linecounter --repo . --min-loc 80 --detailed-structure
Ruby Quality Signals
Files scanned: 4

Column descriptions:
  Churn    = total git commits touching the file (optionally since --since).
  Branches = count of control-flow tokens (sum of per-keyword counts).
  LOC      = non-empty lines of code in the file.
  File     = repository-relative path.

Churn  Branches LOC    File
3      34       189    lib/linecounter/structure_analyzer.rb
3      0        161    test/unit/structure_analyzer_test.rb
2      13       99     lib/linecounter/report.rb
1      3        99     lib/linecounter/branch_analyzer.rb

Detailed structure (all scanned files):
constants
  CONSTANT =                 count=11   avg_loc_per_item=8.27
public_attribute_macros
  public attr_reader         count=2    avg_loc_per_item=1.00
initializer
  initialize                 count=2    avg_loc_per_item=7.00
public_methods
  public def                 count=38   avg_loc_per_item=8.53
private_methods
  private def                count=8    avg_loc_per_item=9.75
```