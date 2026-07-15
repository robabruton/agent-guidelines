---
name: code-review
description: Review code, local changes, branches, files, functions, classes, or small projects for correctness, maintainability, edge cases, and integration risk. Use for inspection at rest; use debug for a concrete failure that needs a fix and explain for understanding without review findings.
when_to_use: Use when the user asks for a general code review, quality check, bug hunt, pre-commit review, branch review, or review of local software work.
argument-hint: "[file|directory|symbol|branch|changes|project]"
allowed-tools: Read Grep Glob
---

Review software work for correctness and practical quality. Use this
skill when the user wants a general review and does not already need a
narrower audit such as security, tests, dependencies, docs, scripts, or
firmware.

This is the default review lens for ordinary code changes. Focus on
issues that can cause bugs, regressions, confusing maintenance, or
integration problems. Do not spend findings on style preferences unless
they create a concrete correctness or maintainability risk.

## Target Selection

Determine the target from the user request:

- No target: review staged and unstaged local changes.
- File path: review that file and nearby callers or tests as needed.
- Directory path: review relevant source under that directory.
- Symbol name: find and review that function, class, type, or module.
- Branch or changes: review the diff against the appropriate base.
- `project`: review primary source surfaces, entry points, and high-risk
  workflows.

For changed-code reviews, inspect both staged and unstaged changes
(`git diff --name-only`, `git diff --cached --name-only`,
`git status --short`).

Prefer `rg --files` to find source, tests, scripts, configuration, and
docs that define the behavior under review. Read enough surrounding
context to understand callers, data flow, and expected behavior before
forming findings.

For broad project reviews, sample the primary entry points, core domain
logic, configuration paths, persistence or I/O boundaries, and tests
before reporting. State the sampled scope so the user understands what
was and was not reviewed.

## Review Areas

### Correctness

- Logic does not match the intended behavior.
- Edge cases, empty input, duplicate input, malformed input, or boundary
  values are mishandled.
- Error handling is missing, misleading, or inconsistent.
- State transitions, ordering, lifecycle, cleanup, or resource ownership
  can break under realistic use.
- Return values, exceptions, status codes, or side effects do not match
  caller expectations.

### Integration and Compatibility

- Changed code no longer matches callers, interfaces, config, generated
  files, documented behavior, or tests.
- Assumptions about paths, current working directory, environment,
  platform, timezone, locale, permissions, or tool availability are
  unsafe.
- Public behavior changes silently without migration, compatibility, or
  documentation consideration.
- Cross-file behavior depends on hidden ordering or shared mutable
  state.

### Maintainability That Affects Behavior

- Control flow is hard to reason about in a way that can hide bugs.
- Names, structure, or duplication make future changes likely to break
  behavior.
- Abstractions are too broad, too leaky, or mismatched with current use.
- Important invariants are implicit and easy for maintainers to violate.
- Comments or docs contradict the code in a way that can mislead future
  work.

Do not report broad architecture preferences unless the current
structure is already causing a concrete bug, confusing behavior, or
likely future breakage.

### Tests as Residual Risk

- Important changed behavior has no obvious test coverage.
- Existing tests would not catch the reviewed issue.
- A regression test is needed for a bug-prone path.

Do not perform a full test-quality audit unless the user asks. If tests
are the main concern, recommend `test-audit`.

## Boundaries

Use specialized skills instead when the main concern is narrower:

- `script-audit` for shell, hooks, installers, setup scripts, filesystem
  mutation, and command automation.
- `security-audit` for exploitable vulnerabilities and threat surface.
- `test-audit` for coverage, assertion strength, and missing tests.
- `dependency-audit` for dependency changes and supply-chain decisions.
- `docs-audit` or `docs-review` for documentation.
- `firmware-review` for embedded, hardware-facing, ISR, RTOS, register,
  DMA, timing, or startup/linker behavior.
- `docstrings` for documentation comments.
- `explain` when the user wants understanding rather than review.

During `code-review`, it is fine to note that a specialized follow-up
would be useful, but do not duplicate the full specialized audit.

## Finding Standard

Each finding must include:

- The file and line or the narrowest available location.
- The condition that triggers the issue.
- The realistic impact.
- A concrete fix direction.

Report only findings that are actionable and likely to matter. Suppress
pure style preferences, speculative concerns, and issues already guarded
by nearby code.

If a concern depends on an assumption, label it as an assumption and say
what would confirm it.

Do not invent findings to fill the format. If the reviewed surface looks
sound, say so and focus the remainder on scope and residual risk.

## Output Format

Lead with findings grouped by severity (High, Medium, Low), one
bullet per finding:

`path:line - Issue. Impact. Suggested fix.`

- **High:** Likely incorrect behavior, data loss, broken workflow,
  serious regression, or unsafe state under realistic use.
- **Medium:** Edge-case bug, integration mismatch, missing error path,
  or maintainability issue likely to cause future defects.
- **Low:** Minor correctness, clarity, or robustness issue with limited
  impact.

After findings, include:

- Surfaces reviewed.
- Tests or commands run, if any.
- Residual risk, including test gaps or specialized audits not
  performed.

If no issues are found, say that clearly and state what was reviewed and
what residual risk remains.
