---
when: optimizing or evaluating performance
load: recall
summary: >-
  Optimize against measurement, not intuition: profile or benchmark
  to find the real cost before changing code, keep the benchmark or
  the before/after numbers with the change, and do not trade
  readability for a speedup you have not measured. Exists because
  guessed-at optimizations usually target the wrong code and leave
  the codebase harder to read for no proven gain.
---
# Performance Rules

## Measure Before Optimizing

- Profile or benchmark to locate the real cost before changing code.
  The bottleneck is often not where intuition points, and an
  unmeasured optimization usually improves the wrong thing.
- State the target: the specific operation, input size, and metric
  (wall time, allocations, throughput) the work aims to improve.
- Optimize the dominant cost first. A large factor on a minor code
  path is not worth a readability cost; a small factor on the hot
  path may be.

## Keep the Evidence With the Change

- Record the before and after numbers for the change, measured the
  same way, so the gain is verifiable rather than asserted.
- When the project supports it, land a repeatable benchmark alongside
  the optimization so later changes can detect a regression.
- If a change is expected to help but was not measured, say so and
  label it as unverified rather than claiming a speedup.

## Do Not Trade Clarity for Unmeasured Gains

- Preserve the clearest correct implementation until a measurement
  shows it is too slow. Complexity added for performance must be
  justified by numbers.
- Comment a non-obvious optimization with what it buys and the
  measurement that justified it, so a later reader does not
  "simplify" it back or preserve it without cause.
- A correctness regression is never an acceptable price for speed;
  verify the optimized path still passes the same tests.
