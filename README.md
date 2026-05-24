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
# or the convenience shim at the repo root:
ruby q.rb --repo /path/to/repo
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
linecounter --repo /path/to/repo --json
linecounter --repo /path/to/repo --top 30 --since 3.months.ago --show-structure-overview
```

## Example Output

```bash
$ linecounter --min-loc 700 --detailed-structure --since 2.months.ago --repo ../hello-world
Ruby Quality Signals
Files scanned: 3

Column descriptions:
  Churn    = total git commits touching the file (optionally since --since).
  Branches = count of control-flow tokens (sum of per-keyword counts).
  LOC      = non-empty lines of code in the file.
  File     = repository-relative path.

Churn  Branches LOC    File
13     253      805    app/models/document.rb
7      66       1193   app/services/pdf_generator.rb
1      146      744    app/services/company_generator.rb

Detailed structure (all scanned files):
module_inclusion
  include                    count=9    avg_loc_per_item=12.11
association
  has_many                   count=7    avg_loc_per_item=2.14
  has_one                    count=2    avg_loc_per_item=2.00
  belongs_to                 count=7    avg_loc_per_item=1.00
public_attribute_macros
  public attr_reader         count=1    avg_loc_per_item=1.00
macros
  scope                      count=10   avg_loc_per_item=20.60
  validates                  count=1    avg_loc_per_item=4.00
  validate                   count=1    avg_loc_per_item=1.00
  after_*                    count=1    avg_loc_per_item=1.00
  enum                       count=2    avg_loc_per_item=4.00
public_class_methods
  public class def           count=2    avg_loc_per_item=1.00
initializer
  initialize                 count=2    avg_loc_per_item=1.00
public_methods
  public def                 count=68   avg_loc_per_item=1.12
private_methods
  private def                count=69   avg_loc_per_item=1.00
```