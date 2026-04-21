# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-04-21

### Added

- Local setup tooling for linking this repository's rules and
  `project-setup` skill into Claude, shared agent, and Codex
  configuration directories.
- Safe local setup behavior, including status and dry-run modes,
  idempotent relinking, forced conflict backups, custom backup paths,
  clear grouped output, and smoke test coverage.
- Reusable project rules for git workflow, docstrings, attribution,
  changelogs, versioning, testing, documentation, configuration,
  scripts, dependencies, backward compatibility, and changelog entry
  quality.
- Target-repository setup workflow, including the `project-setup` skill,
  `project-setup.sh`, project rule assembly, local hook installation,
  initial repository commits, rerun behavior, rule profiles, changelog
  modes, rule source modes, and smoke test coverage.
- Local setup documentation that lists every managed path created or
  updated by `setup.sh`.

### Changed

- Split changelog and versioning guidance into common, date-based, and
  semver-specific rule files.
- Clarified the git workflow rules to reference the split changelog rule
  files and permit the generated initial commit on a new repository.
