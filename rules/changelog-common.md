# Changelog Common Rules

Maintain a `CHANGELOG.md` in the repository root using the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format when a
project opts into changelog maintenance.

## Format

- The file MUST be named `CHANGELOG.md`
- Changes are grouped under these headings, in this order:
  - `### Added` - new features
  - `### Changed` - changes to existing functionality
  - `### Deprecated` - features marked for future removal
  - `### Removed` - features removed in this release
  - `### Fixed` - bug fixes
  - `### Security` - vulnerability fixes
- Omit any group that has no entries for a given section
- Each entry is a bullet point written for humans, not a commit log dump
- Do NOT auto-generate the changelog from git log
- Group related commits into a single human-readable bullet when that is
  clearer than one entry per commit

## Initial Setup

When a project opts into changelog maintenance, create `CHANGELOG.md`
during initial project setup with only the title, short description, and
Keep a Changelog reference. Commit that base file with the initial
repository setup.

Do not add an empty release section during the initial setup commit. Add
the first changelog section only when there is a real change to record.
