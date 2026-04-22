# Versioned Changelog Rules

Use versioned changelog sections for projects that publish releases,
packages, APIs, or other versioned artifacts.

## Section Headings

- An `## [Unreleased]` section sits at the top once there is work in
  progress to record
- Section heading format: `## [X.Y.Z] - YYYY-MM-DD`
- If `[Unreleased]` does not exist yet, create it with the first
  recorded change
- When cutting a release, rename `[Unreleased]` to
  `[X.Y.Z] - YYYY-MM-DD` and add a fresh empty `[Unreleased]` section
  above it for future work
- Link version headings to diffs at the bottom of the file when a remote
  exists

## Workflow

- Update `[Unreleased]` as branch work is completed
- Add an entry once a commit or small group of commits completes a
  describable change
- Do not wait until the branch is finished to write all entries
  retroactively
- The cut from `[Unreleased]` to a release section happens on the
  release branch, never as a direct commit to main
- The changelog update is part of the version bump commit:
  `chore: bump version to X.Y.Z`
- For a single-scope branch with a known release entry, the entry may be
  written directly into the release section as part of the cut commit
