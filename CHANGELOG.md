# Changelog

All notable changes are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2026-07-02

### Added
- `--crud-only-controllers` lists Rails controllers whose public actions are all
  standard RESTful actions (index/show/new/create/edit/update/destroy). Private
  and protected helpers are ignored; a single non-CRUD public action excludes a
  controller. Available in both text and JSON output.
- `--non-crud-controllers` lists the inverse of `--crud-only-controllers`:
  controllers that expose at least one custom (non-RESTful) public action, with
  those extra actions shown. Available in both text and JSON output.
- `--no-churn` skips the per-file git churn computation, which dominates runtime
  on large repositories (one `git log` per file). The Churn column reports 0.

## [0.1.2] - 2026-05-24

### Changed
- Reworded the gem description to remove an em-dash.

Note: 0.3.0 was published from an accidental version jump and yanked; this
release is the intended patch following 0.1.1.

## [0.1.1] - 2026-05-24

### Added
- `rake release` one-command flow (build, tag `vX.Y.Z`, push to RubyGems),
  gated on the test suite so a failing build is never released.
- Gem metadata: `changelog_uri` and `allowed_push_host`; `CHANGELOG.md` is now
  shipped in the gem.

## [0.1.0] - 2026-05-24

### Added
- Initial release. Scans a git repository and reports per-file quality
  signals — non-empty lines of code, git churn, control-flow branching, and
  class-structure counts with average statement lines per item — as text or
  JSON.
- `linecounter` executable; `--repo` defaults to the current directory.
- AST-based analysis via Prism for accurate structure and branch signals
  (no false positives from keywords in strings, comments, or method bodies).

[Unreleased]: https://github.com/roberthopman/linecounter/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/roberthopman/linecounter/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/roberthopman/linecounter/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/roberthopman/linecounter/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/roberthopman/linecounter/releases/tag/v0.1.0
