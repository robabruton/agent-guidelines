# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-04-22

### Added

- Docs audit skill for verifying documentation against actual project
  files, scripts, commands, options, examples, managed paths, and
  generated behavior.
- Firmware review skill for reviewing embedded firmware, drivers, RTOS
  code, ISRs, hardware-facing C/C++, startup code, linker assumptions,
  and device protocols.
- Security audit skill for reviewing exploitable risks across code,
  configuration, dependencies, scripts, deployment, and firmware security
  surfaces based on actual attack surface.
- Script audit skill for reviewing scripts, hooks, setup workflows, and
  command automation for safety, correctness, portability, and
  idempotency.

### Changed

- Added skill metadata policy and invocation-focused frontmatter for
  current skills, including read/search tool pre-approval for audit and
  review skills.
- Renamed the versioned changelog rule file to `changelog-version.md`
  and standardized `project-setup.sh --changelog` canonical values to
  `date` and `version`, with `dated`, `dates`, `versioned`, and
  `versions` accepted as aliases.

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
  modes, rule source modes, and agent file smoke test coverage.
- Local setup documentation that lists every managed path created or
  updated by `setup.sh`.

### Changed

- Split changelog and versioning guidance into common, date-based, and
  semver-specific rule files.
- Clarified the git workflow rules to reference the split changelog rule
  files and permit the generated initial commit on a new repository.
