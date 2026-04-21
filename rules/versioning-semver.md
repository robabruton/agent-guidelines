# Semantic Versioning Rules

Use Semantic Versioning (`MAJOR.MINOR.PATCH`) for projects that have
releases, users, packages, APIs, or other versioned artifacts.

## Version Levels

- `PATCH` (`1.0.0` to `1.0.1`): bug fixes, documentation corrections, or other backwards-compatible fixes
- `MINOR` (`1.0.0` to `1.1.0`): backwards-compatible features, capabilities, or meaningful additions
- `MAJOR` (`1.0.0` to `2.0.0`): breaking API, interface, behavior, configuration, data, or workflow changes that users must adapt to

## Release Timing

- A version bump is a release
- Release when there is a meaningful unit of value for users
- Release critical bug fixes immediately as a `PATCH`
- Release completed features or logical batches of related work as `MINOR`
- Release breaking changes as `MAJOR`
- Do NOT bump the version on every commit or every merge

## Release Check

At the end of any branch that changes user-facing behavior, public APIs,
configuration, install behavior, documented workflows, or packaged
artifacts, evaluate whether a release is warranted.

- If a release is warranted, recommend the appropriate version bump
- If no release is warranted, say so explicitly during final review
- Do not silently skip the release decision for versioned projects

## Version Recording

- Tag releases with annotated tags, such as `git tag -a v1.0.0 -m "release 1.0.0"`
- If the project has a version file such as `package.json`,
  `pyproject.toml`, or `version.h`, update it in the release commit
- The release commit may mention the version number when it updates
  versioned project metadata, such as `chore: bump version to 1.2.0`
- Do not put version numbers in unrelated commit messages
- Update the changelog as part of the same release branch before merging
