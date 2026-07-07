---
when: adding, updating, or removing project dependencies or lockfiles
load: recall
summary: >-
  Adding, updating, and removing project dependencies. Prefer
  existing project dependencies, standard libraries, and local
  utilities before adding something new; follow the ecosystem's
  lockfile and version-pinning conventions; remove dependencies
  whose justifying feature has been removed rather than leaving
  unused tooling in place.
---
# Dependency Rules

Dependencies should solve a real project problem and justify their
maintenance, security, and portability cost.

## Adding Dependencies

- Prefer existing project dependencies, standard libraries, and local
  utilities before adding something new
- Add a dependency only when it materially reduces complexity, improves
  correctness, or provides a well-maintained capability the project
  should not implement itself
- Avoid adding dependencies for small helpers that are easy to write and
  maintain locally
- Consider license, maintenance activity, security history, package
  size, and platform support before adding a dependency

## Versioning and Lockfiles

- Follow the package manager's normal lockfile and version pinning conventions
- Commit lockfiles for applications and tools when the ecosystem expects
  reproducible installs
- Do not hand-edit generated lockfiles unless the package manager requires it
- Keep dependency updates scoped so unrelated package changes are easy to review

## Removing and Updating

- Remove dependencies that are no longer used
- Do not keep tooling, packages, plugins, or libraries after the feature
  that needed them is removed
- Treat dependency upgrades as behavior-changing work when they can
  affect runtime, generated output, security, or compatibility
- Note important dependency additions, removals, and upgrades in the
  changelog when they affect users or project operation
