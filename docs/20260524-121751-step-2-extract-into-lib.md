# ADR — Step 2: Extract `q.rb` into a require-able `lib/`

- Date: 2026-05-24 12:17:51 UTC
- Status: Accepted
- Step: 2 of the gem-rebuild plan (see `docs/intention.md`)
- Supersedes: nothing
- Follows: Step 1 — CLI golden-master safety net (commit `3adb7c0`)

## Context

`q.rb` ran all of its logic at the top level, so the code could not be
`require`d and therefore could not be unit-tested. The plan's step 3 (unit
tests) and step 5 (package as a gem) both depend on the logic living behind
require-able seams. Step 1 pinned the CLI's stdout behavior with 8 golden
snapshots, so we can now refactor and *prove* nothing changed.

## Decision

Move all logic out of the top-level script into `Linecounter` modules under
`lib/`, and reduce `q.rb` to a 7-line shim:

```ruby
require_relative "lib/linecounter"
Linecounter::CLI.run(ARGV)
```

The golden tests keep invoking `q.rb` as a subprocess, so the shim preserves
the public CLI contract unchanged.

### Module layout

```
lib/linecounter.rb               entry point; requires the pieces
lib/linecounter/branch_analyzer.rb    BRANCH_TOKENS, .breakdown
lib/linecounter/structure_analyzer.rb STRUCTURE_ITEMS, .statement_span, .counts
lib/linecounter/scanner.rb            .ruby_files, .loc
lib/linecounter/git.rb                .run, .repo?, .churn, .parse_since
lib/linecounter/analyzer.rb           Result struct + .run (per-file orchestration)
lib/linecounter/report.rb             .render -> text / json
lib/linecounter/cli.rb                option parsing + flow
```

The split follows the domain: branch counting, structure analysis, file
scanning, git interaction, orchestration, reporting, and the CLI shell. The
pure pieces (`BranchAnalyzer`, `StructureAnalyzer`, `Scanner.loc`,
`Git.parse_since`) are the seams step 3 will unit-test directly.

## Behavior preservation

This step changes **no behavior**. Verified by:

- All 8 CLI golden snapshots stay green (`rake test`).
- Smoke checks: no-`--repo` still prints the requirement and exits 1;
  `--help` still renders; `ruby -Ilib -e 'require "linecounter"'` loads the
  library with no `q.rb` present.

## Consequences

- Positive: the logic is now require-able and unit-testable; `q.rb` is a thin
  entry point; clear seams exist for the step-4 bug fixes.
- Cost: more files to navigate than a single script (acceptable; matches the
  domain and serves later steps).

## Incidental cleanup

Dropped five regex constants that were defined but never referenced:
`ASSOCIATION_RE`, `MACRO_RE`, `ATTRIBUTE_RE`, `DELEGATE_RE`,
`MODULE_INCLUDE_RE`. Removing dead code cannot change output, and the golden
suite confirms it didn't.

## Known issues now relocated (still to fix in step 4)

The bugs catalogued in `docs/intention.md` moved with the code. Current
locations:

```
Issue                                Now lives in
-----                                -----------
structure_overview avg = 0.00        lib/linecounter/report.rb (#text)
JSON loc overview mis-keyed          lib/linecounter/report.rb (#json)
def self. / initialize double-count  lib/linecounter/structure_analyzer.rb (STRUCTURE_ITEMS)
avg_loc_per_item collapses bodies?   lib/linecounter/structure_analyzer.rb (#statement_span)
```

These remain intentionally unfixed so step 2 stays behavior-preserving. They
will be fixed as deliberate, golden-diffing changes in step 4.
