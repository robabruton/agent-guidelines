---
name: debug
description: Drive a live failure to a verified root-cause fix — reproduce, isolate, diagnose, fix, and land the regression test. Use for concrete failing tests, errors, crashes, wrong results, or regressions; use code-review for inspection at rest and explain for understanding without a fix.
when_to_use: Use when there is a concrete failing behavior to fix — a failing test, an error message, a crash, a wrong result, or a regression. For inspecting code at rest use code-review; for understanding code without fixing it use explain.
argument-hint: "[failing-test|error-message|command|bug-description]"
---

Drive a failure to a fix. Use this skill when something concretely
misbehaves — a failing test, a crash, an error message, a wrong
result, a regression — and the goal is a verified root-cause fix,
not a review of code at rest.

The discipline this skill applies is `rules/debugging.md`: reproduce
before fixing, isolate, fix the cause rather than the symptom, and
land the regression test with the fix.

## Target Selection

Determine the starting point from the user request:

- Failing test: run it and capture the failure.
- Error message or stack trace: locate the emitting code and find a
  command that triggers it.
- Command or workflow that misbehaves: run it and capture actual
  versus expected output.
- Bug description or regression range: find the affected behavior,
  then a command or test that demonstrates it.

If nothing concrete fails — the user wants an assessment of risk or
quality — this is not the right skill; use `code-review` or a
specialized audit instead.

## Workflow

### 1. Reproduce

- Run the failure and capture the exact command, input, environment,
  and output before changing any code.
- If the failure cannot be reproduced, report what was tried and
  stop; any change made without a reproduction is speculative
  hardening and must be labeled as such.

### 2. Isolate

- Minimize the reproduction: cut inputs, configuration, and code
  paths until the failure is as small as it gets.
- Narrow systematically — `git bisect` across a regression range,
  halving the input, disabling stages — rather than reading code and
  hoping to spot the defect.
- Separate the crash site from the origin: trace the bad value or
  state upstream until the first point where it is wrong.

### 3. Diagnose

- State the root cause as a falsifiable sentence ("X returns an
  empty list when the input has no header, and Y indexes it"), and
  check it against the evidence before writing the fix.
- If the evidence supports several candidate causes, test the
  cheapest-to-check first and record what each test ruled out.

### 4. Fix

- Fix the cause at its origin. A guard at the crash site is only
  correct when the analysis shows the crash site is the defect.
- Keep the fix commit free of opportunistic refactoring; other
  improvements go in their own commits.
- When an upstream defect forces a workaround, document the upstream
  cause at the workaround site.

### 5. Verify

- Rerun the original reproduction and show the result.
- Land a regression test in the same branch, and confirm it fails
  against the unfixed code when practical without recreating the
  broken implementation.
- Run the project's relevant test suite to check the fix broke
  nothing else, and report the full result.

## Boundaries

- `code-review` and the audit skills inspect code at rest; this
  skill exists to chase a live failure.
- `explain` builds understanding without changing code; switch to it
  when the user wants to know how something works rather than fix
  it.
- `test-audit` assesses coverage broadly; this skill adds only the
  regression test for the defect it fixes.

## Output

Report, in order:

- The reproduction: command, input, and observed failure.
- The isolation path: what was narrowed or bisected, and what each
  step ruled out.
- The root cause, stated concretely with file and line references.
- The fix and why it addresses the cause.
- Verification evidence: the rerun reproduction, the regression
  test, and the suite result.

If the failure could not be reproduced or the cause could not be
confirmed, say so plainly, report what was ruled out, and label any
mitigation applied as speculative.
