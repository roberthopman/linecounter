# ADR — Foundation audit: visibility-scoping bugs

- Date: 2026-05-24 12:44:26 UTC
- Status: Accepted
- Follows: Step 6 — default --repo to cwd (commit `44c99cd`)
- Scope: post-plan correctness audit of the structure analyzer

## Context

With the gem shipped, we audited the foundation (`StructureAnalyzer#counts`)
for correctness bugs beyond the four catalogued in step 4. Three were found and
confirmed with repros against the real code; all three produced wrong results
on ordinary, valid Ruby.

## Bugs fixed

### A. Visibility leaked across class/module boundaries

`visibility` was a single value that was never reset, and the `stack` that was
supposed to scope it was built but never read (dead code). After any `private`,
every following method — including those in later, sibling classes — was
counted as private.

```ruby
class A; private; def a; end; end
class B; def b; end; def c; end; end   # b, c are public, were counted private
```

### B. Inline `private def` dropped and flipped the section

A line matching `private`/`protected`/`public` set visibility and `next`-ed, so
`private def helper` (and `private attr_reader :x`) was never counted and also
switched the whole section to private for following lines.

### C. `CONST ==` counted as a constant assignment

`CONSTANT_RE` matched the first `=` of `==`, so a comparison at line start
(`STATUS == :active`) was counted as a constant assignment.

## Fix

`counts` now tracks a real scope stack:

- `scopes` — a stack of section-visibilities, one frame per open
  class/module/`class << self`. The current visibility is `scopes.last`.
- `block_stack` — one entry per open `end`-bearing construct, tagged `:scope`
  (class/module/singleton) or `:other` (def, control-flow, `do` block). On
  `end`, the top frame is popped; popping a `:scope` frame restores the
  enclosing section's visibility.
- A new class/module/singleton pushes a frame whose visibility starts public,
  so each scope begins public and sibling/nested scopes are isolated. Nested
  scopes correctly restore the outer section on exit.
- Bare `private`/`protected`/`public` sets the current scope's visibility;
  `private def foo` / `private attr_reader :x` is applied to that one line only.
- Opener detection handles `def`, control-flow keywords, and `do |..|` blocks,
  skips endless methods (`def foo = expr`) and one-line `... end` forms, and
  ignores statement modifiers (`return if x`). `CONSTANT_RE` now uses `=(?!=)`.

## Verification

- All eight golden snapshots are **unchanged** — the fixture exercises
  do-blocks, control flow, statement modifiers, and multiple methods, and still
  produces byte-identical output, evidence the new nesting logic is balanced.
- Six new unit tests cover: cross-class isolation (A), inline `private def` and
  `private attr_reader` (B), nested reset/restore, blocks-inside-methods
  regression, and the comparison-vs-constant case (C). 39 tests green.

## Known limitations (line-based analyzer, left as-is)

- Keywords/macros inside strings, comments, or method bodies can still match
  (`"use if you want"` counts an `if`; `thing.scope(:x)` counts a `scope`).
- `module_function` (bare) does not flip visibility; methods after it count as
  public.
- Methods inside `class << self` are counted as instance defs, not class defs.
- `statement_span` splits on `#`, so `#{interpolation}` can miscount parens.

These need a real parser (e.g. Ripper/Prism) to fix and are out of scope for a
lightweight signals tool; recorded here so the boundary is explicit.
