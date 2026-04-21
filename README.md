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

This is distinct from `project-setup.sh`, which applies repository
standards to a target project.

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
- `changelog-versioned.md` defines versioned changelog section and release cut expectations.
- `versioning-semver.md` defines semantic versioning and release expectations.
- `testing.md` defines verification expectations before merging branch work.
- `documentation.md` defines accuracy and example expectations for project docs.
- `configuration.md` defines repository, local, and secret configuration boundaries.
- `scripts.md` defines safety, UI, idempotency, error handling, and portability expectations for scripts.
- `dependencies.md` defines expectations for adding, updating, and removing dependencies.
- `backward-compatibility.md` defines replacement, removal, migration, and release-impact expectations.

## Skills

Skills live in `skills/` as reusable agent workflows.

- `project-setup` initializes or updates repositories with project standards.

## Project Setup Script

Use `project-setup.sh` to apply the `project-setup` workflow to a
target repository:

```bash
./project-setup.sh --profile codebase --changelog date /path/to/project
```

This script is distinct from any future repository setup command for
developing `agent-guidelines` itself.

Run the smoke tests for the target-repository setup command with:

```bash
tests/project-setup-smoke.sh
```
