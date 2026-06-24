---
when: writing or modifying production code, including comments, sample data, and inline annotations
load: recall
---
# Code Quality Rules

Conventions for writing code that stays correct, honest, and low-noise
over time. These complement the language's own style tooling; they
capture judgment calls that linters do not enforce.

## Single Source of Truth for Version and Identity

Do not hardcode a project's version string in source. Read it from the
one authoritative place — the package manifest or installed package
metadata — so it cannot drift out of sync with the release.

- Expose `version` by querying package metadata at runtime, not by
  duplicating the literal in code.
- Smoke tests must assert the version is a non-empty string of the right
  shape, never a specific value. A test that pins `"1.2.0"` becomes a
  failure the moment the project is bumped.

The same principle generalizes: any fact that has an authoritative home
(a build constant, a config value, a schema) should be read from there,
not re-typed where it is used.

## Never Suppress Diagnostics — Fix the Cause

Do not silence type-checker or linter errors with inline ignore comments
to make a check pass. Fix the underlying issue.

- If a type error is legitimate, correct the code.
- If an optional import is unresolved during type checking, add the
  package to the dev/type-check dependencies so the checker can see it —
  do not ignore the import.
- Treat an ignore comment as a last resort that needs an explicit
  justification, not a routine way to get green.

Suppressed diagnostics hide real problems and erode trust in the check.

## Consistent Terminology

Pick one term per concept and use it everywhere — code, schemas,
identifiers, prompts, comments, and docs. Flip-flopping between two words
for the same thing (e.g. "item" in one place, "record" in another for
the identical entity) is a real maintenance cost and a source of bugs.

- When two concepts are genuinely distinct, give them distinct,
  non-overlapping names and keep the boundary sharp.
- When renaming, change every occurrence; do not leave the old term in
  some layers.

## Realistic Sample, Demo, and Fixture Data

Generated demo, seed, or fixture data must be internally coherent and
believable, not fill-in-the-blank templates.

- Avoid obvious template substitution (`{name}`, `{title}` repeated
  across records) — it reads as synthetic.
- Each record's fields must make sense together as a unit (codes,
  categories, dates, and descriptions that are mutually consistent), not
  independently random selections.
- Group the fields for one record as a single coherent object rather than
  picking each field from an independent pool.

## Visual Alignment of Inline Annotations

When a line carries a trailing inline annotation (an aligned comment, an
`=`-aligned value, a column in an ASCII table), keep it aligned with its
neighbors in the same block.

- Measure the annotation column across the whole block, not just the line
  being edited — the original may itself be misaligned.
- Fix pre-existing misalignment in the same edit, silently. This is
  quality-of-prose cleanup, not a behavior change, so it does not warrant
  its own commit message line.

This is not a CI-enforced rule; it is visible noise that reads as
carelessness if left ragged.
