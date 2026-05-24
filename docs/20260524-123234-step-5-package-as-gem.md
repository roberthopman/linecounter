# ADR — Step 5: Package as a gem

- Date: 2026-05-24 12:32:34 UTC
- Status: Accepted
- Step: 5 of the gem-rebuild plan (see `docs/intention.md`)
- Follows: Step 4 — fix known bugs (commit `e9419a2`)

## Context

This is the "easy change" the whole plan was sequenced toward: with a safety
net (step 1), a require-able library (step 2), unit tests (step 3), and correct
numbers (step 4) in place, packaging is now low-risk mechanical work.

## Decision

Add the standard gem scaffolding around the existing `lib/`:

```
lib/linecounter/version.rb   VERSION = "0.1.0" (required from lib/linecounter.rb)
exe/linecounter              executable shim: require "linecounter"; CLI.run(ARGV)
linecounter.gemspec          metadata, files, executable, dev deps
Gemfile                      source + gemspec (for development)
LICENSE                      MIT
```

Details:

- **Name** `linecounter` (matches the repo). The installed command is
  `linecounter`; `q.rb` stays as a repo-root convenience shim used by the
  golden tests.
- **License** MIT — the de facto Ruby default. Change if you'd prefer another.
- **`required_ruby_version`** `>= 3.0`.
- **Packaged files** scoped with `Dir["lib/**/*.rb", "exe/*", "README.md",
  "LICENSE"]` so the gem ships only runtime code + docs — no `test/`, `docs/`,
  or fixtures.
- **Dev dependencies** `minitest` and `rake` declared in the gemspec; `Gemfile`
  just points at the gemspec. `Gemfile.lock` stays untracked (a library ships a
  gemspec, not a lockfile) — already covered by `.gitignore`.
- **CLI help** banner and examples updated from `ruby q.rb` to `linecounter`
  to match the installed command. No golden covers `--help`, and the
  `--repo PATH is required` message is unchanged, so the golden suite is
  unaffected.
- **README** gains an Installation section and uses `linecounter` in usage and
  examples, with a note on running from a checkout.

## Verification

- `gem build linecounter.gemspec` builds cleanly (no warnings after dropping the
  redundant `homepage_uri` metadata that duplicated `source_code_uri`).
- Packaged file list confirmed: `LICENSE`, `README.md`, `exe/linecounter`, and
  the eight `lib/` files — nothing else.
- Installed into a throwaway `GEM_HOME` and ran the installed binary:
  `linecounter --repo . --top 2` produces correct output; bare `linecounter`
  prints the requirement and exits 1. `require "linecounter"` resolves with no
  `-Ilib`, proving the load path is right.
- Full suite still green (32 tests).

## Remaining

Publishing (`gem push`) is intentionally left to a human — it is the one
public, irreversible action. Step 6 (default `--repo` to the current directory)
is the last planned change.
