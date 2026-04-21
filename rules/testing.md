# Testing Rules

Verify every branch before it is merged. The amount of testing should
match the risk, scope, and behavior changed by the branch.

## Test Selection

- Use the smallest reliable check that proves the changed behavior works
- Prefer existing project test commands, scripts, and conventions
- Prefer unit tests for isolated logic and fast feedback when the project has a unit test framework
- Add or update automated tests when changing behavior that can be tested automatically
- Use manual verification when no automated check exists yet, and record what was checked
- Do not add broad test infrastructure unless it clearly supports the current project

## What to Verify

- New behavior works as intended
- Existing behavior touched by the branch still works
- Unit-level behavior is covered for non-trivial logic when practical
- Error paths, edge cases, and invalid inputs are covered when relevant
- Documentation examples and setup commands still match reality
- Installer, migration, and configuration changes are tested in both success and failure paths when practical

## Merge Expectations

- Do not merge a branch with known failing tests unless the branch is explicitly replacing the failing behavior
- If a test cannot be run, say why and describe the remaining risk
- If no test suite exists, perform a focused manual review of the changed files
- The final branch summary should state what was tested or why testing was not run
