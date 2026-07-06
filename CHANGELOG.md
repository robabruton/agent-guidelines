# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-07-06

### Added

- `setup.sh --status` verifies each assembled context file against
  the current rules and reports it as current, stale, or missing,
  and `--dry-run` previews only the files an install would actually
  change. A stale block previously reported as managed, so an
  out-of-date install was invisible.
- `tests/hooks-smoke.sh` verifies the installed hook snippets in a
  temporary repository: guard rejections and passes, merge
  exemptions, and pre-push ref handling including deletions and
  tags.

### Changed

- `setup.sh` delivers global rules through the assembled context
  files only and no longer installs per-rule symlinks into
  `~/.claude/rules/`. A harness that reads both channels loaded the
  same rule text twice in every conversation. Run `setup.sh --prune`
  to remove links left by earlier installs.
- The always-tier rules `git-workflow.md`, `git-messages.md`, and
  `no-plans-on-main.md` state each expectation once instead of
  restating it across sections: branch naming, commit-when-done,
  message-file handling, merge message format, and the local/ layout
  each have a single home, with cross-references where two rules
  meet. Every requirement is retained at a lower standing context
  cost.
- `development-attribution.md` states that the installed hooks
  reject every authorship trailer regardless of who is named and
  that human collaborators are credited in commit body prose, so the
  rule and its enforcement describe the same boundary.
- The `docs-audit` and `docs-review` triggers open with the factual
  accuracy versus writing quality distinction and cross-reference
  each other, so trigger text alone routes to the right skill.
- The `merge-requests` rule is tiered `recall`: it appears in the
  router table with a pull/merge request trigger instead of being
  inlined into every conversation's global context. Project profiles
  still include it in generated instruction files.
- `project-setup/SKILL.md` matches `project-setup.sh`: the profile
  rule lists and canonical rule order include every rule the script
  applies, per-project skill installation and its source modes are
  documented, and the script is named as the authoritative
  implementation to run when available.

### Fixed

- The pre-push branch-name guard validates the branches actually
  being pushed, read from the ref list git supplies on stdin,
  instead of the currently checked-out branch. Deletions and tag
  pushes are not name-checked, and the `revert/` prefix is accepted
  alongside the other Conventional Commit types.
- The commit guards are portable and self-hosting: the staged
  attribution guard runs under plain POSIX sh and lists every staged
  file carrying tool attribution, both attribution patterns are
  assembled from split fragments so committing the hook definitions
  themselves does not trip the staged guard, and the conventional
  commit guard counts subject length in characters rather than bytes
  and points `git revert`'s default subject at the `revert:` type.
  Existing repositories need `project-setup.sh` re-run to pick up
  the updated hook blocks.

## 2026-06-25

### Fixed

- `agent-memory-report.sh` recognizes the tiering fields
  (`load`, `status`, `type`) and the `name:` slug whether they
  appear as flat top-level YAML keys or nested under a
  `metadata:` map. The script scopes its key lookups to the
  frontmatter block and accepts any indentation, so both the
  layout the templates show and the layout some hosts produce
  on save are reported correctly. Body prose containing
  `type:` no longer masks a real missing-tiering entry.
- Git hook templates exempt merge commits so a `--no-ff` merge
  into `main` with the mandated `Merge branch '<name>'`
  subject is no longer rejected. `commit-msg-conventional`
  skips the Conventional Commits format check and the
  60-character length cap during a merge, and
  `pre-commit-main-branch` allows the main-branch guard to
  pass when finishing a conflicted merge with `git commit`.
  Ordinary authored commits remain subject to both checks.
  Existing repositories need `project-setup.sh` re-run to pick
  up the corrected hook blocks.

### Changed

- `agent-memory/SKILL.md` documents host frontmatter
  normalization alongside the existing loader-verification
  guidance so future sessions auditing a normalized store know
  the layout is expected and harmless.
- `git-workflow.md` clarifies that the no-direct-commits-to-
  main discipline applies to authored work commits and that
  `--no-ff` merge commits are the only commits that originate
  on `main`. `git-messages.md` clarifies that the `commit-msg`
  hook exempts merge commits from the Conventional Commits
  format check and the 60-character length cap so the
  mandated `Merge branch '<name>'` subject is allowed.

## 2026-06-24

### Added

- `LICENSE` file containing the PolyForm Noncommercial License 1.0.0,
  with a short pointer from the README. Noncommercial use is freely
  permitted; commercial use requires a separate agreement with the
  copyright holder.
- `project-setup.sh` now prepends a generated-file meta-header and a
  `## Project-Specific Notes` placeholder section above the marker
  block when it creates a new `CLAUDE.md` or `AGENTS.md`. The
  preamble sits outside the marker pair so it is preserved across
  re-runs; users can replace the placeholder text with their own
  project-specific guidance without it being overwritten. Smoke test
  asserts the preamble exists after the first run and survives the
  idempotent second run.
- `.github/workflows/smoke.yml` runs every check on push to `main`
  and on every pull request: shellcheck (warning level and above) on
  every shell script in the repository, frontmatter validation that
  every rule file declares `when:` and a valid `load:` value, a
  consistency check that every rule name referenced by
  `project-setup.sh` exists in `rules/` and every skill name in
  `setup.sh`'s `GLOBAL_SKILLS` exists in `skills/`, and both smoke
  scripts.
- Skill router section in the assembled global context. `setup.sh`
  now appends a `## Situational Skills — Invoke When Triggered`
  table listing every skill in `skills/` that is not in
  `GLOBAL_SKILLS`, with each row built from the skill's
  `when_to_use` SKILL.md frontmatter. Non-global skills are
  discoverable from the same global context file as the rule
  router without being loaded on every conversation.
- `rules/README.md` catalog with a paragraph per rule grouped
  by always-tier versus recall-tier, plus a short intro
  covering frontmatter and tiering. Renders as the directory
  README when browsing the `rules/` tree. The root `README.md`
  Rules section replaces its per-rule bullet list with a
  pointer to the new catalog so the catalog is the single
  source for "what each rule covers."
- `setup.sh --prune` removes symlinks in the rule and skill
  harness directories whose resolved targets point into this
  repository's `rules/` or `skills/` tree but are no longer in
  the managed link set. Symlinks whose targets resolve outside
  the repository are left untouched, so user-created links in a
  managed directory are never affected. Honors `--dry-run` for
  preview.

- `lib/assemble-rules.sh` shared library exposing marker constants, a
  frontmatter stripper, a frontmatter field reader, a rule-block
  assembler, a managed-block updater, a managed-block remover, and a
  router-table builder. Reused by `project-setup.sh` and `setup.sh`.
- `when` and `load` YAML frontmatter on every rule file. `load: always`
  marks the six rules that belong in the global set; `load: recall`
  marks the situational ones the model should read on demand.
- Global context-file assembly for Claude Code, OpenCode, Pi, and
  Codex. `setup.sh` now writes a managed block into
  `~/.claude/CLAUDE.md`, `~/.config/opencode/AGENTS.md`,
  `~/.pi/agent/AGENTS.md`, and `~/.codex/AGENTS.md` containing the
  always-loaded rules inlined plus a router section listing every
  recall-tier rule with its trigger and a stable reference path.
- `--include-skill`, `--exclude-skill`, and `--skills-source` flags on
  `project-setup.sh`. Opted-in skills install into
  `<project>/.agents/skills/<skill>/`, where every supported harness
  discovers them by walking up from cwd. Symlink mode adds
  `.agents/skills/` to the project's local git exclude so the links
  stay out of source control; copy mode tracks the copied skill tree.
- `--dry-run` flag on `project-setup.sh` that previews every action
  (created, updated, unchanged, skipped, warnings) without writing
  files, creating symlinks, configuring git, installing hooks, or
  making commits. Flags whether the managed context block would be
  created, replace an existing block, or append at the end because no
  marker pair was found. Smoke test exercises the full preview flow
  and asserts no state is left behind.
- `~/.agent-guidelines/rules` directory symlink so router pointer
  paths resolve to the repository's `rules/` no matter where the
  checkout lives.

### Changed

- `git-messages.md` requires a subject-only commit message for
  renames, file moves, typo fixes, comment corrections, and
  narrowly scoped mechanical edits. A body for these almost
  always over-explains the change and should be deleted before
  committing.
- `.github/workflows/smoke.yml` rule frontmatter check skips
  `README.md` by basename so a directory-level catalog file
  under `rules/` is not subject to the per-file delimiter,
  `when:`, and `load:` assertions that apply to rule files.
- `pre-commit-attribution` hook catches additional AI-tool
  attribution shapes: the adjective form (an AI subject
  prefixing a contribution verb as a hyphenated modifier) and
  the "developed" verb in both prepositional and footer forms.
  The hook also runs its file-scan loop in the main shell so
  its rejection propagates to the hook exit code.
- `project-setup.sh` summary reports the skill source mode
  alongside the rule source mode so both modes are visible
  without having to inspect arguments or environment.
- `project-setup.sh` summary lists the final selected rules
  (in canonical order, counted) and the final selected skills
  (after include/exclude) so the rules and skills that get
  inlined into the assembled `CLAUDE.md` and `AGENTS.md` are
  visible without opening the generated files.
- Skill catalog moved from `SKILLS.md` at the repository root to
  `skills/README.md` so it renders as the directory README when
  browsing the `skills/` tree. The root `README.md` pointer updates
  to the new path; the catalog content moves unchanged.
- `setup.sh` now installs a curated global set instead of every rule
  and skill. Rules are derived from `load: always` frontmatter; skills
  come from a small `GLOBAL_SKILLS` array. The global set today is six
  rules (`agent-conduct`, `development-attribution`, `git-workflow`,
  `git-messages`, `no-plans-on-main`, `merge-requests`) and four skills
  (`agent-memory`, `code-review`, `explain`, `project-setup`), each
  skill mirrored into the Claude, Agents, and Codex skill directories.
  Non-global rules and skills remain available per project through
  `project-setup.sh`.
- `setup.sh` summary now reports context-file activity (created,
  updated, current, removed, cleared) separately from symlink counters.
- `project-setup.sh` sources `lib/assemble-rules.sh` instead of
  carrying its own copy of the marker-block code. Assembled CLAUDE.md
  and AGENTS.md output is unchanged because the library strips
  frontmatter on inlining.
- README managed-paths table now lists the curated global set together
  with the two assembled context files and the rule-store symlink, and
  documents that everything else is opt-in per project.
- `no-plans-on-main.md` now prescribes mirroring the project's tracked
  layout inside `local/` (e.g. `local/plans/`, `local/scripts/`) so
  the local equivalent of any tracked path is easy to find under a
  single excluded root.
- `no-plans-on-main.md` pre-stage checklist now treats the branch name
  itself as a fifth artifact to scan, and the banned-phrase list now
  explicitly catches "followup", "follow-up", "next-step", "to-do",
  "upcoming", and similar "more work after this" phrasings that slip
  into branch names because conversational language flows into branch
  names without scrutiny.
- Cleaned `project-setup.sh` by removing two unused `MARKER_BEGIN` /
  `MARKER_END` local-alias variables left over from the library
  extraction, and annotated the router-table `printf` in
  `lib/assemble-rules.sh` with an explicit `shellcheck disable=SC2016`
  comment explaining why the single-quoted format string is correct.
- Commit-subject hook (`commit-msg-conventional` snippet) now caps
  the total subject line at 60 characters and rejects anything over
  that. The 50-character target stays as the soft goal — subjects
  51-60 chars trigger the existing warning but are accepted. The
  rule wording in `git-messages.md` records the relationship: target
  50, hard limit 60 enforced by the hook.
- Renamed `LICENSE` to `LICENSE.md` so GitHub renders the
  markdown-formatted PolyForm Noncommercial 1.0.0 text with proper
  headings, emphasis, and the autolinked source URL instead of as
  plain text. README link updated. License detection on the sidebar
  widget is unaffected (works for either filename).

### Fixed

- `project-setup.sh` creates the initial commit when the target
  is an existing git repository that has no commits, rather than
  skipping because the repository was not initialized by the
  current run. The dry-run preview shows the planned initial
  commit in this case too.
- Assembled `CLAUDE.md`, `AGENTS.md`, and the global context
  files render as proper markdown documents: every rule's H1
  title is demoted to H2 (with deeper headings shifted in step,
  capped at H6) so the assembled file has hierarchical
  structure instead of eleven sibling H1s, and the separator
  between rules is a single blank line instead of two.
  Hash characters inside fenced code blocks are left
  untouched.

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
