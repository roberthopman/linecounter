# ADR — Step 4: Fix the known structure bugs

- Date: 2026-05-24 12:28:34 UTC
- Status: Accepted
- Step: 4 of the gem-rebuild plan (see `docs/intention.md`)
- Follows: Step 3 — unit tests (commit `31bb15c`)

## Context

Steps 1–3 deliberately preserved behavior, pinning the known bugs at both the
CLI (golden) and unit level. This is the first step that *changes* behavior.
Each fix is a deliberate diff to the golden snapshots and, where relevant, to a
unit test — so the change is visible and reviewed, exactly as the plan intends.

## Bugs fixed

### 1. `def self.x` / `def initialize` double-counted as public defs

`def self.build_default` matched both the class-method item (`DEF_SELF_RE`) and
the plain instance-method item (`DEF_RE` matches `self`); `def initialize`
matched both the initializer item and the instance-method item. Each was
counted twice.

Fix (`structure_analyzer.rb`): introduce `instance_def?`, which is true only
for a `def name` that is neither `def self.` nor `def initialize`, and use it
in the public/protected/private instance-method matchers. A def now lands in
exactly one category.

Effect on the fixture: `public_methods` 7 → 4 (widget 4→2, calc 3→2);
`public_class_methods` (1) and `initializer` (2) unchanged.

### 2. Structure-overview `avg_loc_per_item` always 0.00 (text)

The overview divided by a per-type count but read LOC from the *item-keyed*
`structure_item_loc_overview` using a *type* key — always a miss, so always
0.00. Fix (`report.rb`): add `type_loc_sum`, which rolls item LOC up to the
type, and divide by that. Non-zero types now report real averages (1.00 on
this fixture, where every statement span is one line).

### 3. JSON loc overview mis-keyed

`--json --show-structure-overview` emitted `structure_item_loc_overview`
(item-keyed) alongside `structure_overview` (type-keyed), which don't align,
while `--detailed-structure` emitted item *counts* but no item *LOC*. Fix
(`report.rb`): the overview now emits type-keyed `structure_loc_overview`
(aligns with `structure_overview`); the detailed section now emits the
item-keyed `structure_item_loc_overview` (aligns with
`structure_item_counts_overview`). Each section is now internally consistent.

## Investigated, not a bug

### 4. `avg_loc_per_item` ≈ 1.00 for methods

`statement_span` measures the *statement* (a def's signature plus any
line-continued parameters), not the method body. On the test fixture every
signature is one line, so the average is 1.00; the README's own example output
shows `public def avg_loc_per_item=1.12` on a real repo, confirming this is the
intended "statement lines per item" metric, not body length. Left unchanged.

## Verification

- Golden diffs are limited to the three structure-related snapshots
  (`structure_overview`, `detailed_structure`, `json`); `default`,
  `min_loc_5`, `branch_count`, and `since` are untouched, confirming churn /
  branches / LOC are unaffected.
- The step-3 unit test that pinned the double-count was flipped to assert the
  corrected single-count behavior. Aggregation tests (overview == sum of
  per-file counts) still pass unchanged.
- Each regenerated golden was eyeballed against hand-computed expectations
  before being committed.

32 tests green.

## Edge case noted (out of scope)

A `def self.x` written under `private`/`protected` no longer counts as a
private/protected instance method (correct — it is a class method) but also is
not counted by `public_class_method_def` (which still requires public). The
fixture has no such case and no golden covers it; revisit only if needed.
