---
when: writing or updating user-facing documentation, READMEs, guides, or example commands
load: recall
summary: >-
  User-facing documentation must describe behavior that currently
  exists rather than behavior that is planned. Examples should be
  runnable or marked illustrative, alternatives listed side by side
  must use parallel references, one term per concept across the
  docs, and documentation lives where the project already keeps
  related documentation rather than being duplicated.
---
# Documentation Rules

Documentation must describe the project as it actually works. Do not
document planned behavior as if it already exists.

## Accuracy

- Update documentation when user-facing behavior, setup, configuration,
  commands, or workflows change
- Major features should include documentation in the same branch, or the
  final branch review should explicitly ask whether documentation should
  be added
- Keep README instructions aligned with the current repository contents
- Describe limitations, prerequisites, and assumptions when they affect usage
- Remove stale instructions instead of leaving contradictory guidance in place
- If documentation is deliberately excluded from the current change,
  record the current scope and reason without promising another change

## Examples

- Examples should be runnable or clearly marked as illustrative
- Commands should use realistic paths, flags, and filenames
- Do not include placeholder URLs, package names, or commands in final
  documentation unless the placeholder is intentional and explained
- Keep examples small enough to verify during review

## Consistency

- When listing alternatives side by side (two tools, two options), keep
  the references parallel — link to the same kind of target page for each
  (both homepages, or both install pages) and use parallel phrasing.
  Mismatched references read as careless.
- Use terminology consistent with the code and the rest of the docs: one
  term per concept, everywhere.

## Scope

- Prefer documenting behavior where the project already keeps related documentation
- Documentation may live in `docs/`, the root `README.md`, package or
  module READMEs, comments, or another project-appropriate location
- Do not duplicate long explanations across files unless each copy
  serves a different audience
- When documentation changes without behavior changes, keep the commit
  scoped as documentation only
