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

- Tag releases with annotated tags
- Use `-m` for a short single-line annotation, such as
  `git tag -a v1.0.0 -m "release 1.0.0"`
- Use `-F <file>` for multiline tag messages so release prose can be
  wrapped and edited normally
- If the project has a version file such as `package.json`,
  `pyproject.toml`, or `version.h`, update it in the release commit
- The release commit may mention the version number when it updates
  versioned project metadata, such as `chore: bump version to 1.2.0`
- Do not put version numbers in unrelated commit messages
- Update the changelog as part of the same release branch before merging

## Tag Message Format

Write tag messages as concise release summaries for humans reviewing the
project history or deciding whether to upgrade. Do not use Conventional
Commits format, dump individual commits, or list internal function names.

For single-purpose releases, a short one-line annotation is enough:

```sh
git tag -a v1.0.1 -m "release 1.0.1: footer layout fix"
```

For releases with meaningful user-facing or maintainer-facing content,
write a subject plus one or more wrapped body paragraphs:

```text
release 1.3.0: XLSX export and CDRL seeding

Adds XLSX export support and CDRL seed data so maintainers can generate
reviewable deliverable tables from parsed requirements without manual
spreadsheet setup.
```

- Group related changes into human-readable outcomes
- Use bullet lists only when the release combines distinct areas and
  prose would hide important separation
- Wrap body lines at 72 characters
- Draw the content from the changelog entries for the version, condensed
  into a release-level summary

Write multiline messages to a temp file and pass it with `-F`:

```sh
git tag -a v1.3.0 <commit-sha> -F /tmp/tag-v1.3.0.txt
```

Do not use repeated `-m` flags for multiline release notes; each `-m`
creates a separate paragraph and gives poor control over wrapping.

When tagging retroactively, set `GIT_COMMITTER_DATE` intentionally if the
tag metadata should reflect an earlier release date instead of the date
the backfilled tag is created. Use the actual release timestamp when it
is known; otherwise, choose the tagged commit's author or committer date
deliberately:

```sh
GIT_COMMITTER_DATE="<release-timestamp>" \
  git tag -a v1.3.0 <commit-sha> -F /tmp/tag-v1.3.0.txt
```
