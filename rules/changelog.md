# Changelog Rules

Maintain a `CHANGELOG.md` in the repository root using the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## Format

- The file MUST be named `CHANGELOG.md`
- Changes are grouped under these headings, in this order:
  - `### Added` — new features
  - `### Changed` — changes to existing functionality
  - `### Deprecated` — features marked for future removal
  - `### Removed` — features removed in this release
  - `### Fixed` — bug fixes
  - `### Security` — vulnerability fixes
- Omit any group that has no entries for a given section
- Each entry is a bullet point written for humans, not a commit log dump
- Do NOT auto-generate the changelog from git log — write meaningful, user-facing descriptions

## Initial Setup

When a project opts into changelog maintenance, create `CHANGELOG.md`
during initial project setup with only the title, short description, and
Keep a Changelog reference. Commit that base file with the initial
repository setup.

Do not add an empty `[Unreleased]` section or an empty dated section in
the initial commit. For versioned projects, add `[Unreleased]` with the
first real recorded change. For date-based projects, add the first dated
section with the first real recorded change.

## Section headings

There are two styles depending on whether the project uses versioning:

### Versioned projects (semver)

- An `## [Unreleased]` section sits at the top once there is work in progress to record
- Section heading format: `## [X.Y.Z] - YYYY-MM-DD`
- If `[Unreleased]` does not exist yet, create it with the first recorded change
- When cutting a release, rename `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD` and add a fresh empty `[Unreleased]` section above it for future work
- The changelog update is part of the version bump commit: `chore: bump version to X.Y.Z`
- Link version headings to diffs at the bottom of the file when a remote exists

### Non-versioned projects (date-based)

- Section heading format: `## YYYY-MM-DD`
- Do NOT use an `[Unreleased]` section, even temporarily
- Write each change directly into the dated section for the day the change is made
- If today's dated section does not exist yet, create it at the top of the dated entries
- If multiple changes land on the same day, append them to the existing dated section for that day rather than creating a duplicate heading
- This makes the calendar date itself the only cut point for non-versioned projects

## Workflow

- An entry does not need to map 1:1 to commits — group related commits into a single human-readable bullet point
- For versioned projects: the cut from `[Unreleased]` to a release section ALWAYS happens on the release branch, never as a direct commit to main
- For date-based projects: write the changelog entry under today's date as part of the branch work before merging
- For versioned projects: the cut is part of the `chore: bump version to X.Y.Z` commit on the release branch

### Multi-commit branches

- For versioned projects: update `[Unreleased]` as you work — add an entry once a commit or small group of commits completes a describable change
- For date-based projects: update today's dated section as you work; do not wait until the branch is finished to write all entries retroactively

### Single-scope branches

- For versioned projects: if the branch is a single describable change and you know the entry upfront, you MAY skip the intermediate `[Unreleased]` round-trip
- In that case, write the entry directly into the release section as part of the cut commit — `[Unreleased]` stays empty throughout
- For date-based projects: just write the entry directly into today's dated section
