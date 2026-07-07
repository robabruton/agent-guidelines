---
when: investigating a bug, test failure, or regression
load: recall
summary: >-
  Discipline for driving a failure to a fix: reproduce before
  changing code, minimize the reproduction, fix the root cause
  rather than the symptom, land the regression test in the same
  branch as the fix, and rerun the original reproduction to confirm
  it. Exists because symptom patches and unreproduced "fixes" let
  the same defect resurface later in a harder-to-trace form.
---
# Debugging Rules

## Reproduce Before Fixing

- Reproduce the failure and capture the exact command, input, and
  output before changing any code. A fix for an unreproduced bug is
  a guess.
- If the failure cannot be reproduced, say so plainly and treat any
  change as speculative hardening rather than a fix, with the
  remaining risk stated.

## Isolate the Cause

- Minimize the reproduction: cut inputs, configuration, and code
  paths until the failure is as small as it gets. Small reproductions
  localize the defect and become the regression test.
- Prefer systematic narrowing — `git bisect`, halving the input,
  disabling half the pipeline — over reading code and hoping to spot
  the defect.
- Distinguish where the failure appears from where it originates. The
  crash site is often downstream of the defect; fixing the crash site
  alone usually masks it.

## Fix the Root Cause

- Patch the cause, not the symptom. Suppressing an error, widening a
  timeout, or adding a guard at the crash site is only correct when
  the analysis shows that point is genuinely the defect.
- When an upstream defect forces a workaround, document the upstream
  cause at the workaround site so maintainers can judge when it can
  be removed.
- Keep the fix separate from opportunistic refactoring; one commit
  fixes the defect, other improvements go in their own commits.

## Verify the Fix

- Land the regression test in the same branch as the fix, and confirm
  it fails against the unfixed code when that is practical without
  recreating the broken implementation.
- Rerun the original reproduction after the fix and report the
  observed result; a green suite alone does not prove the specific
  failure is gone unless a test encodes it.
- Testing expectations for the branch as a whole are in
  `testing.md`.
