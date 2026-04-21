# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-04-21

### Added

- Git workflow rules for branch discipline, merge readiness, commit rhythm, merge strategy, and conventional commit messages
- Docstring rules for documenting functions, types, constants, callbacks, and non-trivial code
- Development attribution rules for keeping tool-generated attribution out of committed files
- Changelog rules for initial setup, section formats, and update workflow
- Versioning rules for semantic version levels, release timing, release checks, tags, and version metadata
- Testing rules for selecting checks, verifying behavior, and reporting merge readiness
- Documentation rules for keeping project docs accurate, current, and verifiable
- Configuration rules for committed config, local-only files, environment variables, and secrets
- Script rules for safe execution, help output, preview behavior, idempotency, cleanup, and portability
- Dependency rules for evaluating additions, managing lockfiles, and removing unused packages or tools
- Backward compatibility rules for breaking changes, replacements, removals, migrations, and release impact
- `project-setup` skill scaffold for initializing or updating repositories with project standards
- Asset templates for project setup files and local git hook snippets
- Local git exclude behavior for agent configuration files in `project-setup`
- Project rule assembly behavior for `CLAUDE.md` and `AGENTS.md`
- Marker-based local git hook installation behavior in `project-setup`
- Initial commit behavior for repositories created by `project-setup`
- Rerun, idempotency, and final summary behavior in `project-setup`
- Split changelog and versioning rules by common, date-based, and semver-specific behavior
- Rule profile, changelog mode, versioning mode, and symlinked rule source behavior in `project-setup`
- Initial-commit exception in the main-branch guard hook template
- `project-setup.sh` command for applying project setup behavior to target repositories
- Git workflow references to split changelog rule files
