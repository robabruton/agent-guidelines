---
name: test-audit
description: Audit tests for meaningful behavioral coverage, weak assertions, missing edge cases, and focused opportunities to add or improve tests.
when_to_use: Use when reviewing tests, checking whether branch behavior is covered, improving coverage, adding regression tests, or deciding which tests are missing.
argument-hint: "[file|directory|branch|changes|behavior]"
---

Audit tests for whether they protect the behavior users and callers
depend on. Use this skill when tests changed, a bug fix needs regression
coverage, a branch is close to merge, coverage is weak, or the user asks
which tests are missing.

This skill has two modes:

- Audit mode: report coverage gaps, weak assertions, brittle tests, and
  focused test recommendations.
- Edit mode: add or improve tests when the user asks to add tests,
  improve coverage, or close gaps.

Do not edit tests during audit-only requests. Do not turn a targeted
test request into a broad test rewrite.

This is not a general code review. Mention implementation defects only
when they affect testability or explain why existing tests cannot
protect the intended behavior.

## Target Selection

Determine the target from the user request:

- No target: audit tests related to changed code.
- Test file: audit that test file and the behavior it claims to cover.
- Source file: audit tests for that source file.
- Directory: audit tests and source behavior under that directory.
- Branch or changes: audit tests for staged and unstaged changes.
- Behavior or bug description: find related source and tests.

For changed-code targets, inspect both staged and unstaged changes
(`git diff --name-only`, `git diff --cached --name-only`,
`git status --short`).

Prefer `rg --files` to find test files and source files. Common test
locations include `test`, `tests`, `spec`, `__tests__`, `fixtures`,
language-specific test directories, and CI or smoke test scripts.

Identify the test runner, fixture style, naming conventions, and normal
local verification commands before recommending or adding tests.

## Audit Areas

### Behavior Coverage

- Changed behavior has no direct test.
- Tests cover the happy path but miss negative, boundary, empty,
  duplicate, malformed, permission, timeout, or partial-failure cases.
- A bug fix lacks a regression test that would fail before the fix.
- Public API, CLI, config, generated output, or compatibility behavior
  is not covered.
- Important interactions across files are only tested through unrelated
  side effects.
- Setup, teardown, cleanup, rollback, or idempotency behavior is
  user-visible but untested.

### Assertion Quality

- Assertions only check that code runs, not that the result is correct.
- Tests assert implementation details instead of externally observable
  behavior.
- Expected values are too broad, too loose, or derived from the same
  code under test.
- Snapshots, golden files, or output checks are too large to diagnose or
  too vague to catch regressions.
- Tests omit important error messages, exit codes, return values, state
  changes, emitted events, or filesystem effects.
- Failure tests assert only that an error occurred, not that the failure
  is the expected one.

### Isolation and Reliability

- Tests depend on order, timing, random values, local machine state,
  environment variables, current working directory, locale, timezone, or
  network access.
- Tests mutate shared state without cleanup.
- Fixtures are reused in a way that hides test intent.
- Mocks are so broad that the behavior being tested cannot fail.
- Slow or flaky tests are mixed into fast local checks without a reason.
- Tests pass only because a previous test created data, files, cache, or
  process state.

### Coverage Improvement

- Coverage reports show untested branches, statements, or functions, but
  the missing code is not connected to meaningful behavior.
- Coverage goals encourage low-value tests instead of risk-based tests.
- A small number of focused tests would cover multiple important paths.
- Existing tests can be extended without duplicating setup or obscuring
  intent.
- Untested high-risk code handles parsing, permissions, destructive
  actions, external input, compatibility, or persistence.

Treat coverage numbers as a signal, not the goal. Prefer tests that
protect behavior over tests that only execute lines.

## Test Generation

When the user asks to add tests, improve coverage, or close gaps, write
focused tests after the audit:

1. Identify the smallest behavior gap worth testing.
2. Match the project's existing test framework, naming, fixture style,
   and assertion style.
3. Prefer regression tests, boundary tests, and externally observable
   behavior over implementation-detail tests.
4. Add only the setup needed for the behavior under test.
5. Run the focused test command when practical.
6. If a coverage command exists and the user asked for coverage, run the
   smallest relevant coverage check.

Do not add broad speculative tests just to raise a coverage number. Do
not introduce a new test framework, dependency, fixture system, or test
layout unless the user explicitly asks or the project already requires
it.

If the project has no test framework, recommend a minimal test strategy
instead of inventing a large test harness.

When adding regression tests, make the test fail for the old bug when
that can be done without recreating the broken implementation. If the
old failure cannot be reproduced, state the limitation in the summary.

## Finding Standard

Each finding must include:

- The behavior or risk that is not protected.
- The existing test or missing test location.
- Why the gap matters.
- A concrete test to add or assertion to strengthen.

Suppress concerns that would only improve style, duplicate existing
coverage, or test implementation details without protecting behavior.

Rank findings by risk, not by coverage percentage. A missing regression
test for a user-visible bug is more important than an uncovered trivial
branch.

## Output Format

For audit-only use, lead with findings grouped by severity (High,
Medium, Low), one bullet per finding:

`path:line - Gap. Suggested test or assertion.`

- **High:** behavior is unprotected; name the test to add.
- **Medium:** an assertion is too weak; say how to strengthen it.
- **Low:** coverage or reliability improvement.

After findings, include:

- Tests and source behavior audited.
- Commands or coverage reports checked, if any.
- Residual risk and tests not run.

For edit mode, summarize the tests added and updated (one bullet per
path, stating the behavior covered or the assertion improved) and the
verification command run, or why none was run.

If tests are already adequate, say that clearly and state what was
inspected.
