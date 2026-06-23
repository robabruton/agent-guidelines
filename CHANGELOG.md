# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-06-23

### Added

- `agent-conduct.md` rule covering safe conduct on a real codebase:
  backing up before destructive actions, confirming irreversible or
  outward-facing actions, treating sign-off assets as read-only, verifying
  point-in-time facts before asserting them, and reporting outcomes
  honestly.
- `no-plans-on-main.md` rule for keeping roadmaps and forward-looking
  phrasing out of permanent history, with a banned-phrase pre-stage check
  across commits, descriptions, and merge bodies.
- `code-quality.md` rule for single-source-of-truth versions, never
  suppressing diagnostics, consistent terminology, realistic sample data,
  and aligned inline annotations.
- `engineering-judgment.md` rule for explicit choices over auto-detection,
  not designing against a single instance, single source of truth per
  datum, one writer per fact, and reference-not-porting.
- `environment-hygiene.md` rule for dependency install location,
  regenerating moved environments, target-platform compatibility, and
  preferring platform CLIs.
- `merge-requests.md` rule for pull/merge request descriptions: required
  sections, each commit standing on its own, no local-only state, and
  cross-repository context.
- `agent-memory` skill for maintaining a durable, file-based memory store
  across sessions, with starter templates and a read-only report script.

### Changed

- `git-workflow.md` now covers letting commits emerge instead of
  pre-planning a counted list, naming branches from the work, and the
  protected-default-branch flow.
- `git-messages.md` now covers history that describes what is (no
  reverted-work, pre-existing, tag-move, downstream-consumer, or
  before/after narration), consistent level of detail, and stronger
  temporary-message-file cleanup.
- `testing.md` now covers running the full check before pushing, no
  hardcoded dates in tests, and testing build and pipeline steps locally
  first.
- `documentation.md` now covers consistency of parallel references and
  terminology.
- `development-attribution.md` now covers keeping tooling references out
  of ignore files, configs, and paths via an allowlist, and keeping
  specific model or vendor names out of source.

## 2026-04-24

### Changed

- Standardized rule file Markdown formatting with wrapped prose and
  bullets for consistent agent readability.
- Expanded git workflow guidance for branch name validation, branch
  scope corrections, hook handling, pre-merge review, post-merge
  cleanup, push timing, and local-only files.
- Split commit, merge, amendment, and temporary message file guidance
  into a dedicated `git-messages.md` rule.
- Clarified that commit message subjects should target 50 characters
  while allowing slight overages for clarity.
- Corrected semver tag and release message formatting guidance to avoid
  hard-wrapped prose that renders with unintended line breaks.
- Clarified git workflow guidance to require `git commit -F` for
  multiline commit messages and cleanup of temporary commit, merge, tag,
  and release message files.
- Clarified semver release tag guidance for professional annotated tag
  messages, including when to use single-line `-m` annotations versus
  multiline `-F` release summaries.

## 2026-04-22

### Added

- Code review skill for general correctness, maintainability, edge-case,
  and integration-risk review when no narrower audit lens fits.
- Dependency audit skill for reviewing dependency necessity,
  maintenance, security, licensing, lockfile consistency, and
  supply-chain risk.
- Docstrings skill for adding and updating language-appropriate
  documentation comments for public symbols and non-trivial code while
  preserving accurate existing docs.
- Docs audit skill for verifying documentation against actual project
  files, scripts, commands, options, examples, managed paths, and
  generated behavior.
- Docs review skill for reviewing documentation as writing for clarity,
  structure, tone, grammar, style, completeness, and task flow.
- Explain skill for understanding code, files, workflows, commands,
  project concepts, changes, and error paths without editing files.
- Firmware review skill for reviewing embedded firmware, drivers, RTOS
  code, ISRs, hardware-facing C/C++, startup code, linker assumptions,
  and device protocols.
- Security audit skill for reviewing exploitable risks across code,
  configuration, dependencies, scripts, deployment, and firmware security
  surfaces based on actual attack surface.
- Script audit skill for reviewing scripts, hooks, setup workflows, and
  command automation for safety, correctness, portability, and
  idempotency.
- Test audit skill for reviewing behavioral coverage, assertion quality,
  brittle tests, and focused opportunities to add missing tests.

### Changed

- Clarified that merge commit messages should use one body paragraph by
  default while allowing multiple paragraphs when they improve clarity.
- Added skill metadata policy and invocation-focused frontmatter for
  current skills, including read/search tool pre-approval for audit and
  review skills.
- Renamed the versioned changelog rule file to `changelog-version.md`
  and standardized `project-setup.sh --changelog` canonical values to
  `date` and `version`, with `dated`, `dates`, `versioned`, and
  `versions` accepted as aliases.

### Fixed

- Aligned `setup.sh` summary output when labels such as `backup path:`
  are longer than the default summary label width.

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
