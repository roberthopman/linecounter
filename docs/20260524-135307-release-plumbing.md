# ADR — One-command release plumbing

- Date: 2026-05-24 13:53:07 UTC
- Status: Accepted
- Follows: bound prism dependency (commit `025b8e7`)
- Scope: `rake release` workflow

## Context

0.1.0 was published manually (`gem build` + `gem push`). To make subsequent
releases one step and hard to get wrong, wire up Bundler's gem tasks with
sensible guards.

## Decision

- `Rakefile` requires `bundler/gem_tasks`, which adds `build`, `install`,
  `install:local`, `build:checksum`, and `release` (tag `v#{version}`, build,
  and push to RubyGems).
- The `release` task is enhanced to depend on `test`, so a failing suite aborts
  the release before anything is tagged or pushed.
- Gemspec metadata:
  - `allowed_push_host = "https://rubygems.org"` — `release`/`gem push` refuse
    any other host, preventing accidental publication elsewhere.
  - `changelog_uri` — surfaces the changelog link on the gem page.
- `CHANGELOG.md` added (Keep a Changelog format) with the 0.1.0 entry, and
  shipped in the gem (`spec.files`).

## Release procedure from now on

```
edit lib/linecounter/version.rb        # bump per SemVer
update CHANGELOG.md                     # move Unreleased -> the new version
git commit -am "Release vX.Y.Z"
rake release                           # runs tests, tags vX.Y.Z, pushes to RubyGems
```

`rake release` requires a clean working tree and prompts for the RubyGems MFA
OTP on push.

## Verification

- `rake -T` lists the release tasks; `release[remote]` is described as
  "Create tag v0.1.0 and build and push ... to https://rubygems.org"
  (confirming `allowed_push_host`).
- `rake test` (the release prerequisite) runs green: 40 tests.
- `rake build` produces `pkg/linecounter-0.1.0.gem`.

## Note

0.1.0 is already on RubyGems but may not have a matching `v0.1.0` git tag (it
was pushed manually). The CHANGELOG compare links assume that tag; create it
(`git tag v0.1.0 <commit> && git push origin v0.1.0`) if you want the history to
line up. Future versions get their tags automatically via `rake release`.
