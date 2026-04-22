# Skills

Skills live in `skills/` as reusable agent workflows. Each skill should
cover a concrete workflow that benefits from named, repeatable
instructions rather than restating the project rules.

## Current Skills

### `project-setup`

Initializes or updates a repository with shared project rules, git hooks,
commit standards, local excludes, changelog setup, and agent instruction
files.

Use this skill for new repositories and existing repositories that need
the project standards applied or refreshed. The workflow is intended to be
safe to rerun.

### `script-audit`

Audits shell scripts, git hooks, installers, setup workflows, and command
automation for safety, correctness, portability, and idempotency.

Use this skill when reviewing automation that creates, modifies, links,
moves, removes, backs up, or reports on files and project state.
