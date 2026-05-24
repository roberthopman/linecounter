# ADR — Remove q.rb; test the shipped executable

- Date: 2026-05-24 13:29:19 UTC
- Status: Accepted
- Follows: adopt Prism (commit `4a9a430`)
- Scope: file-naming compliance with gem conventions

## Context

A review of the file layout against the standard `bundle gem` structure found
everything compliant except `q.rb` — a single-letter script at the repo root
left over from the original tool. It was:

- not shipped in the gem (the gemspec packages only `lib/`, `exe/`, README,
  LICENSE);
- redundant with `exe/linecounter` (both are thin shims calling
  `Linecounter::CLI.run(ARGV)`);
- used only as the subprocess the golden tests invoked, plus one README line.

## Decision

Delete `q.rb`. Point the golden master at the real executable, run the standard
way for a gem checkout: `ruby -I<lib> exe/linecounter`. `test_helper` now
exposes `LIB` and `EXE` instead of `Q_RB`.

This removes the non-standard file and improves the tests: the golden master
now exercises the actual binary users run, not a parallel shim.

## Verification

- `exe/linecounter` produces byte-identical output to the old `q.rb` (both call
  `CLI.run(ARGV)` on the same code), so all eight golden snapshots are
  unchanged. 40 tests green.
- README "from a checkout" note now shows only `ruby -Ilib exe/linecounter`.

## Notes

The standard layout is otherwise unchanged and compliant: entry point
`lib/linecounter.rb`, namespaced code under `lib/linecounter/`, command
`exe/linecounter`, `linecounter.gemspec`. The single-word module `Linecounter`
matches the single-word gem name; no rename needed.

Historical ADRs and `intention.md` still reference `q.rb` as the accurate
record of earlier steps and are intentionally left untouched.
