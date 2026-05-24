# Rebuilding linecounter — Intention

## The goal

Turn `q.rb` (today a single 370-line script) into **linecounter**, a tool we
can confidently ship as a gem to the Ruby ecosystem — installable, testable,
and usable on any repo from the outside.

## The guiding principle

> "For each desired change, make the change easy (warning: this may be hard),
> then make the easy change." — Kent Beck

The meaningful change is *ship as a gem with confidence*. Writing a gemspec is
the easy change — it is not what makes shipping hard. What makes it hard is the
absence of a safety net around code we already know contains bugs. So the work
is sequenced to **make the change easy first**, then make the easy change.

## What made it hard (the starting state)

```
Blocker                          Consequence
-------                          -----------
No tests at all                  Can't refactor or fix bugs without fear
Logic runs at load (top level)   Can't require it -> can't unit-test it
Known + suspected bugs           We'd be shipping wrong numbers
Single 370-line script           No seams to change one thing safely
```

## The strategy

Build the net before touching the code; refactor under the net; fix bugs as
deliberate, reviewable diffs; package last.

```
1. Safety net      ◀ pin current behavior at the CLI boundary (no code change)
2. Extract         ▶ move logic into require-able lib/, q.rb becomes a shim
3. Unit-test       ▶ test the pieces, especially structure aggregation
4. Fix bugs        ▶ each fix is an intentional diff to the golden snapshots
5. Package         ▶ gemspec, exe/, version, license
6. Zero-config     ▶ default --repo to the current directory 
```

Steps 1–2 change *no behavior*. Step 4 is where behavior changes, and only
there, visibly, in review.

## Decisions

```
Decision           Choice                  Why
--------           ------                  ---
Test framework     Minitest                Ruby stdlib, zero deps, fits a CLI gem
Bug handling       Pin now, fix later      Separate refactor from behavior change
First move         CLI golden master       Only test writable before refactoring
```

## How the safety net works

Behavior is pinned at the **CLI boundary** (argv in, stdout out) — the one seam
that already exists before any refactor. Tests run `q.rb` against a frozen
fixture repo and compare stdout to stored snapshots in `test/golden/`.

The fixture is deterministic on every machine because `test/support/repo_builder.rb`:

  - scripts a fixed commit history, so churn (commits-per-file) is constant
  - sets fixed commit dates, so `--since` results are constant
  - nulls `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_SYSTEM`, so no user config leaks in
  - rewrites a `# rev: N` marker for older revisions, so the file at HEAD stays
    byte-identical to the fixture on disk

The only nondeterministic output field, the JSON `generated_at` timestamp, is
normalized before comparison.

```
Run tests              UPDATE snapshots (intentional only)
---------              -----------------------------------
rake test              UPDATE_GOLDEN=1 rake test
```

A passing golden suite after a change means the change is behavior-preserving.
A golden diff means behavior changed — acceptable only when we meant it (a bug
fix), and reviewed as such.

## Known issues to fix (as deliberate diffs in step 4)

```
Issue                                Where            Status
-----                                -----            ------
structure_overview avg = 0.00        q.rb:348         pinned, to fix
  (LOC summed by item key, divided
   by type key -> always misses)
JSON loc overview mis-keyed too      q.rb:310-311     pinned, to fix
def self. / def initialize also       q.rb:171-175     pinned, to review
  counted as plain public def
avg_loc_per_item = 1.00 everywhere   statement_span   to investigate
  (may collapse multi-line bodies)   (q.rb:178)
```

## Status

  - [x] Step 1 — safety net (8 golden snapshots, green)
  - [ ] Step 2 — extract into require-able lib/
  - [ ] Step 3 — unit tests
  - [ ] Step 4 — fix bugs
  - [ ] Step 5 — package as gem
  - [ ] Step 6 — default --repo to cwd
