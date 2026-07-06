---
name: docs-audit
description: Audit documentation for factual accuracy against actual project files, scripts, commands, options, examples, managed paths, and generated behavior.
when_to_use: Use for factual accuracy of documentation — verifying that README files, setup instructions, CLI examples, managed path lists, skill catalogs, rule references, or changelog guidance match repository reality. For writing quality, use docs-review instead.
argument-hint: "[file|directory|project|changes]"
allowed-tools: Read Grep Glob
---

Audit documentation for factual accuracy against the repository's actual
files, scripts, commands, configuration, generated output, and supported
workflows. Use this skill to find stale examples, broken references,
incorrect option names, missing required usage details, and docs that no
longer match behavior.

This is not a general writing review. Do not report tone, grammar,
style, or structure issues unless they create ambiguity, incorrect usage,
missing information, or a realistic user mistake.

## Target Selection

Determine the audit target from the user request:

- No target: audit changed documentation and nearby behavior it
  describes.
- File path: audit that documentation file.
- Directory path: audit documentation under that directory.
- `project`: audit primary project documentation and generated-reference
  surfaces.

For changed-doc audits, inspect both staged and unstaged changes. Use
`git diff --name-only`, `git diff --cached --name-only`, and
`git status --short` when available.

Prefer `rg --files` to find documentation and referenced artifacts.
Likely targets include README files, `SKILLS.md`, rule files, skill
files, changelog guidance, docs directories, command examples, setup
instructions, generated file descriptions, and tables of managed paths.

## Verification Sources

Use primary project sources before making findings:

- Script usage text and argument parsing.
- Test and smoke test expectations.
- Actual filenames, directories, symlinks, and managed paths.
- Skill frontmatter and installed skill directories.
- Rule filenames and rule text.
- Configuration files and generated config state.
- Help output, status output, dry-run output, and generated files when
  those commands can be run safely.
- Generated documentation sources or templates when docs are produced
  from another file.

Do not rely only on surrounding prose when a script, test, file, or
generated artifact can verify the claim.

## Audit Areas

### Commands and Options

- Documented commands that no longer exist or have the wrong path.
- Options, values, aliases, defaults, or examples that do not match
  parser behavior or help text.
- Required arguments omitted from examples.
- Commands shown in the wrong working directory.
- Verification commands that do not match available tests or scripts.

### Files, Paths, and Links

- Referenced files, directories, rules, skills, hooks, assets, or
  generated outputs that do not exist.
- Managed path tables that do not match setup or install logic.
- Renamed files still referenced by old names.
- Broken relative links or paths.
- Local-only files described as tracked project artifacts, or tracked
  files described as local-only.

### Behavior and Workflow Claims

- Setup, install, remove, status, dry-run, or force behavior described
  differently from the implementation.
- Changelog, versioning, branch, commit, or merge guidance that conflicts
  with rules or scripts.
- Idempotency, backup, conflict, or generated-file behavior overstated or
  understated.
- Skill catalog entries that do not match current skill directories or
  frontmatter.
- Generated documentation that is edited directly when the source
  template or generator should be updated instead.

### Examples and Snippets

- Examples that cannot run as written.
- Examples that use stale option names, filenames, branch names, modes,
  or paths.
- Output snippets that no longer match actual output in meaningful ways.
- Copyable snippets that omit required prerequisites or context.

### Completeness for User Tasks

- Missing prerequisite, setup, or verification step that prevents a user
  from completing the documented task.
- Supported modes or common choices omitted from reference docs.
- Important safety behavior, local-only behavior, or destructive behavior
  not documented where users need it.

## Review Process

1. Identify each factual claim, command, path, option, mode, example, and
   generated behavior the docs present.
2. Verify claims against primary project sources.
3. Run safe read-only, help, status, dry-run, or smoke-test commands when
   useful and appropriate.
4. For changed docs, inspect the related implementation or tests instead
   of reviewing only the changed lines.
5. Report only mismatches, omissions, or ambiguities that can mislead a
   user or break a documented workflow.

Do not run commands that mutate user files, install software, remove
files, change git state, contact the network, or require elevated
privileges unless the user explicitly asks for that execution. Prefer
`--help`, `--status`, `--dry-run`, smoke tests using temporary
directories, and static inspection.

Do not report purely editorial preferences. If wording, structure, or
grammar is the problem, explain the concrete user-facing risk it creates.

## Finding Standard

Each finding must include:

- The documentation location.
- The claim or instruction that is wrong, stale, incomplete, or
  misleading.
- The primary source that contradicts or verifies the issue.
- The user impact.
- A concrete fix.

Suppress a concern when it is only a writing preference, cannot be
verified from available project sources, or does not affect user
understanding or task completion.

If verification depends on an environment, platform, or external tool
that was not available, label it as an assumption to verify rather than a
confirmed finding.

Separate confirmed documentation mismatches from assumptions. Do not
state that a command, path, output, or generated artifact is wrong unless
the project source of truth confirms the mismatch.

## Output Format

Lead with findings grouped by severity:

```text
High
- path:line - Issue. Source of truth. Suggested fix.

Medium
- path:line - Issue. Source of truth. Suggested fix.

Low
- path:line - Issue. Source of truth. Suggested fix.

Assumptions To Verify
- path:line - Claim that needs environment-specific confirmation.
```

Use these severities:

- **High:** A documented command, option, path, setup step, or safety
  claim is wrong and likely to break user workflow or cause risky action.
- **Medium:** Documentation is stale, incomplete, or ambiguous enough to
  mislead users under normal conditions.
- **Low:** Minor factual drift, missing reference detail, or unclear
  wording with limited user impact.

After findings, include:

- Documentation surfaces audited.
- Primary sources checked.
- Commands or tests run, if any.
- Residual risk, especially examples or platform behavior that could not
  be verified.

If no issues are found, say that clearly and still state what was audited
and what was not verified.
