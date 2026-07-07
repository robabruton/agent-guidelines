---
when: writing tests, modifying existing tests, or verifying a branch before merge or push
load: recall
summary: >-
  Verify every branch before it merges, sized to the risk and scope
  of the change. Test selection (smallest reliable check, prefer
  existing project conventions), what to verify (new behavior,
  existing behavior touched, error paths, documentation examples),
  running the project's full check suite before pushing, no
  hardcoded dates in tests, and reproducing expensive remote
  pipeline steps locally first.
---
# Testing Rules

Verify every branch before it is merged. The amount of testing should
match the risk, scope, and behavior changed by the branch.

## Test Selection

- Use the smallest reliable check that proves the changed behavior works
- Prefer existing project test commands, scripts, and conventions
- Prefer unit tests for isolated logic and fast feedback when the
  project has a unit test framework
- Add or update automated tests when changing behavior that can be
  tested automatically
- Use manual verification when no automated check exists yet, and record
  what was checked
- Do not add broad test infrastructure unless it clearly supports the current project

## What to Verify

- New behavior works as intended
- Existing behavior touched by the branch still works
- Unit-level behavior is covered for non-trivial logic when practical
- Error paths, edge cases, and invalid inputs are covered when relevant
- Documentation examples and setup commands still match reality
- Installer, migration, and configuration changes are tested in both
  success and failure paths when practical

## Run the Full Check Before Pushing

Run the project's complete check suite before pushing, not a convenient
subset.

- Run every gate the project's CI runs — formatter check, linter, type
  check, tests. Passing one is not passing all of them.
- Do not filter out slow tests in the final pre-push run or in reported
  test evidence; the slow tests exist to catch real breakage. Report the
  full count.

## No Hardcoded Dates in Tests

Never hardcode calendar dates in test bodies, fixtures, or test data.
Compute them relative to the current date with offsets.

- A test that seeds a "recent" date or asserts against a fixed date
  passes for a while, then silently breaks when the calendar moves past
  the baked-in assumption.
- Compute "old" and "recent" values as offsets from today. This applies
  to filenames, log entries, timestamps in fixtures, and snapshot data.
- If a date genuinely must be pinned (parsing a known historical format),
  make the time-independence explicit by injecting a fixed clock, not by
  assuming the test runs soon enough.

## Test Build and Pipeline Steps Locally First

Before pushing something that triggers an expensive or hard-to-unwind
remote process — a tag that starts a release build, an image build, a
deployment — reproduce that step locally first.

- A local build catches most failures (missing files, build errors,
  misconfiguration) cheaply, before a remote pipeline fails and a
  published tag or artifact has to be deleted and recreated.
- A local run cannot catch every environment-specific issue (credentials,
  remote-only scopes), but it eliminates the common, avoidable failures.

## Merge Expectations

- Do not merge a branch with known failing tests unless the branch is
  explicitly replacing the failing behavior
- If a test cannot be run, say why and describe the remaining risk
- If no test suite exists, perform a focused manual review of the changed files
- The final branch summary should state what was tested or why testing was not run
