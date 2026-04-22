# agent-guidelines

Reusable project guidelines for AI coding agents.

This repository is a starting point for collecting rules, skills, and setup conventions that can be reused across agent-driven development tools.

## Local Tool Setup

Use `setup.sh` to link this repository's rules and skills into local
tool configuration directories:

```bash
./setup.sh --status
./setup.sh --dry-run
./setup.sh --install
```

Output uses aligned status labels and color when supported. Use
`--no-color` or set `NO_COLOR=1` for plain output.

Use `--backup-path <path>` with `--force` to choose where conflicting
files, directories, or foreign symlinks are moved before replacement.
Without an override, backups are written under
`$HOME/.agent-guidelines/backups/YYYYMMDD-HHMMSS/`.

### Managed Paths

| Kind | Managed path | Source |
| --- | --- | --- |
| Rule | `$HOME/.claude/rules/git-workflow.md` | `rules/git-workflow.md` |
| Rule | `$HOME/.claude/rules/development-attribution.md` | `rules/development-attribution.md` |
| Rule | `$HOME/.claude/rules/configuration.md` | `rules/configuration.md` |
| Rule | `$HOME/.claude/rules/testing.md` | `rules/testing.md` |
| Rule | `$HOME/.claude/rules/documentation.md` | `rules/documentation.md` |
| Rule | `$HOME/.claude/rules/docstrings.md` | `rules/docstrings.md` |
| Rule | `$HOME/.claude/rules/scripts.md` | `rules/scripts.md` |
| Rule | `$HOME/.claude/rules/dependencies.md` | `rules/dependencies.md` |
| Rule | `$HOME/.claude/rules/changelog-common.md` | `rules/changelog-common.md` |
| Rule | `$HOME/.claude/rules/changelog-date.md` | `rules/changelog-date.md` |
| Rule | `$HOME/.claude/rules/changelog-version.md` | `rules/changelog-version.md` |
| Rule | `$HOME/.claude/rules/versioning-semver.md` | `rules/versioning-semver.md` |
| Rule | `$HOME/.claude/rules/backward-compatibility.md` | `rules/backward-compatibility.md` |
| Skill | `$HOME/.claude/skills/project-setup` | `skills/project-setup` |
| Skill | `$HOME/.claude/skills/docs-audit` | `skills/docs-audit` |
| Skill | `$HOME/.claude/skills/docs-review` | `skills/docs-review` |
| Skill | `$HOME/.claude/skills/firmware-review` | `skills/firmware-review` |
| Skill | `$HOME/.claude/skills/script-audit` | `skills/script-audit` |
| Skill | `$HOME/.claude/skills/security-audit` | `skills/security-audit` |
| Skill | `$HOME/.agents/skills/project-setup` | `skills/project-setup` |
| Skill | `$HOME/.agents/skills/docs-audit` | `skills/docs-audit` |
| Skill | `$HOME/.agents/skills/docs-review` | `skills/docs-review` |
| Skill | `$HOME/.agents/skills/firmware-review` | `skills/firmware-review` |
| Skill | `$HOME/.agents/skills/script-audit` | `skills/script-audit` |
| Skill | `$HOME/.agents/skills/security-audit` | `skills/security-audit` |
| Skill | `$HOME/.codex/skills/project-setup` | `skills/project-setup` |
| Skill | `$HOME/.codex/skills/docs-audit` | `skills/docs-audit` |
| Skill | `$HOME/.codex/skills/docs-review` | `skills/docs-review` |
| Skill | `$HOME/.codex/skills/firmware-review` | `skills/firmware-review` |
| Skill | `$HOME/.codex/skills/script-audit` | `skills/script-audit` |
| Skill | `$HOME/.codex/skills/security-audit` | `skills/security-audit` |

Run the smoke tests for the local tool setup command with:

```bash
tests/setup-smoke.sh
```

## Rules

Rules live in `rules/` as Markdown files.

- `git-workflow.md` defines branch, commit, merge, and commit message expectations.
- `docstrings.md` defines documentation comment expectations for code changes.
- `development-attribution.md` defines attribution boundaries for committed project files.
- `changelog-common.md` defines shared changelog format and initial setup expectations.
- `changelog-date.md` defines date-based changelog section and workflow expectations.
- `changelog-version.md` defines versioned changelog section and release cut expectations.
- `versioning-semver.md` defines semantic versioning and release expectations.
- `testing.md` defines verification expectations before merging branch work.
- `documentation.md` defines accuracy and example expectations for project docs.
- `configuration.md` defines repository, local, and secret configuration boundaries.
- `scripts.md` defines safety, UI, idempotency, error handling, and portability expectations for scripts.
- `dependencies.md` defines expectations for adding, updating, and removing dependencies.
- `backward-compatibility.md` defines replacement, removal, migration, and release-impact expectations.

## Skills

Skills live in `skills/` as reusable agent workflows.

See `SKILLS.md` for the current skill catalog.

## Project Setup Script

Use `project-setup.sh` to apply the `project-setup` workflow to a
target repository:

```bash
./project-setup.sh --profile codebase --changelog date /path/to/project
```

Run the smoke tests for the target-repository setup command with:

```bash
tests/project-setup-smoke.sh
```
