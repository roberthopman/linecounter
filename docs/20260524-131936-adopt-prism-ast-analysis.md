# ADR — Adopt Prism (AST) for structure and branch signals

- Date: 2026-05-24 13:19:36 UTC
- Status: Accepted
- Follows: foundation audit — visibility bugs (commit `1bc9f0b`)
- Scope: replace the regex/line-based analyzers with Prism AST walking

## Context

The previous foundation-audit ADR catalogued limitations inherent to a
line/regex scanner: keywords and macros matched inside strings, comments, and
method bodies; `module_function` and `class << self` unhandled; `statement_span`
miscounting `#{interpolation}`. It noted these need a real parser. Ruby ships
Prism (a default gem since 3.3, 0.19 here), so we adopt it.

## Decision

Rewrite `BranchAnalyzer` and `StructureAnalyzer` as `Prism::Visitor`s. The
public interfaces are unchanged — `BranchAnalyzer.breakdown(content)` returns
the same bucket hash, `StructureAnalyzer.counts(content)` returns the same
`[type_counts, item_counts, item_loc_sums]` — so `Analyzer` and `Report` are
untouched and the item taxonomy (keys/types/labels/order) is preserved.

- `prism` is declared as a runtime dependency in the gemspec (`>= 0.19`).
- `StructureAnalyzer` walks class/module/singleton scopes, tracking visibility
  per scope; macros, constants, and defs are attributed only at structure level
  (`@method_depth == 0`), so declarations inside method bodies are no longer
  miscounted. `def self.x` and `class << self` defs are class methods;
  `initialize` is the initializer; inline `private def` applies to one node.
- `item_loc_sums` now uses real node line spans
  (`end_line - start_line + 1`), so `avg_loc_per_item` measures actual
  definition length instead of the old signature-line heuristic.
- `BranchAnalyzer` counts AST nodes: `IfNode` split into if / elsif (by
  keyword) / ternary (nil keyword); `UnlessNode`, `CaseNode`/`CaseMatchNode`,
  `WhenNode`/`InNode`, `While`/`Until`, `Rescue`/`Ensure`, explicit `BeginNode`
  only, `AndNode`/`OrNode` (now covering `&&`/`and` and `||`/`or`), `ReturnNode`.

## Behavior changes (deliberate, in the golden snapshots)

All eight golden combos changed; each change was reviewed against the fixtures:

- **Branch counts dropped and are now accurate.** The regex counted every `?`
  as a ternary, so predicate methods (`name.present?`, `x.zero?`) were false
  positives — widget 7→5 branches (ternary 2→0), calc 12→9 (ternary 3→0).
  Keywords in strings/comments no longer count.
- **`avg_loc_per_item` now reflects size.** e.g. `public def` 1.00 → 7.00,
  `initialize` 1.00 → 3.50 on the fixture. Single-line declarations
  (include, has_many, scope, attr_reader) stay 1.00.
- **Structure type/item _counts_ are unchanged** — Prism reproduces the
  step-4-correct counts, confirming the rewrite preserved classification while
  upgrading accuracy and span measurement.

## Verification

- Unit tests rewritten for AST semantics: branch tests assert predicate-`?` is
  not a ternary, string/comment keywords are ignored, `and`/`or` count, and
  method-level rescue counts rescue not begin; structure tests assert real LOC
  spans and that macros inside method bodies are not counted. The visibility
  bug repros from the prior audit still pass (Prism handles them natively).
- 40 tests green. `gem build` clean. README example regenerated from this repo.

## Remaining limitations (now genuinely minor)

- Macro detection is by message name on receiverless calls, so a same-named
  call at class-body level (e.g. a local method called `store`) still counts as
  that macro — inherent to not resolving semantics, acceptable for a DSL-aware
  signals tool.
- Parse errors fall back to Prism's best-effort tree (error-tolerant), so a
  syntactically broken file yields partial signals rather than none.
