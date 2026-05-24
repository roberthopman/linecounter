# Changelog

All notable changes are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-24

### Added
- Initial release. Scans a git repository and reports per-file quality
  signals — non-empty lines of code, git churn, control-flow branching, and
  class-structure counts with average statement lines per item — as text or
  JSON.
- `linecounter` executable; `--repo` defaults to the current directory.
- AST-based analysis via Prism for accurate structure and branch signals
  (no false positives from keywords in strings, comments, or method bodies).

[Unreleased]: https://github.com/roberthopman/linecounter/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/roberthopman/linecounter/releases/tag/v0.1.0
