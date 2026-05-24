# ADR — Step 6: Default `--repo` to the current directory

- Date: 2026-05-24 12:34:27 UTC
- Status: Accepted
- Step: 6 of 6 — final step of the gem-rebuild plan (see `docs/intention.md`)
- Follows: Step 5 — package as a gem (commit `44814bc`)

## Context

Step 1 made `--repo` required as a deliberate, temporary simplification so the
golden master had a single, unambiguous entry contract while we refactored.
The end goal (and the pre-rebuild behavior) is zero-config: an installed
`linecounter` should just work in the repo you're standing in. This step
restores that.

## Decision

`--repo` now defaults to the current directory.

- `cli.rb`: drop the "`--repo` is required" guard; default with
  `options[:repo] ||= "."`. The existing git-repo check still runs, so an
  invalid or non-git path aborts with "Not inside a git repository: <path>".
- Help text: the `--repo` description changes from "(required)" to
  "(default: current directory)", and a bare `linecounter` example is added.
- README: the `--repo` option and Examples preamble updated; a no-argument
  example added.

## Behavior change and the safety net

This flips the one behavior step 1 introduced, so the golden test that pinned
it was replaced rather than regenerated:

- removed `test_requires_repo` (asserted the requirement message + non-zero
  exit);
- added `test_defaults_repo_to_current_directory` — runs the CLI with
  `chdir: fixture` and no `--repo`, and asserts the output equals the existing
  `default.txt` golden (proving `.` resolves to the cwd and produces the same
  result as `--repo <fixture>`);
- added `test_aborts_when_current_directory_is_not_a_git_repo` — runs in a
  non-git tmpdir and asserts the abort on stderr + non-zero exit.

The seven flag-combo golden snapshots are untouched: they pass `--repo`
explicitly, so the default has no effect on them.

## Verification

- 33 tests green.
- Manual: `linecounter --top 2` from the repo root (no `--repo`) scans the
  current repo; running in a non-git tmpdir prints "Not inside a git
  repository" and exits 1.

## Status

All six planned steps are complete. The library is extracted, unit- and
golden-tested, the known bugs are fixed, it is packaged as an installable gem,
and it runs zero-config. The only remaining action is the human-only
`gem push` to publish.
