---
name: script-audit
description: Audit shell scripts, git hooks, installers, setup workflows, and command automation for safety, correctness, portability, and idempotency.
when_to_use: Use when reviewing shell scripts, git hooks, setup scripts, installers, migration scripts, Makefile recipes, CI command scripts, or command snippets that modify files or project state.
argument-hint: "[file|directory|project|changes]"
allowed-tools: Read Grep Glob
---

Audit scripts and automation surfaces for practical failure modes. Use
this skill when asked to review shell scripts, git hooks, setup scripts,
installers, migration scripts, command snippets, or repository automation
that creates, modifies, links, moves, or removes files.

## Target Selection

Determine the audit target from the user request:

- No target: audit changed shell scripts, hooks, and automation files.
- File path: audit that script, hook, or command-oriented file.
- Directory path: audit relevant scripts and hooks under that directory.
- `project`: audit repository automation surfaces such as setup scripts,
  hooks, CI scripts, and documented command examples.

For changed-file audits, inspect both staged and unstaged changes
(`git diff --name-only`, `git diff --cached --name-only`,
`git status --short`).

Prefer `rg --files` to find likely targets. Include files with shell
shebangs, `.sh`, `.bash`, `.zsh`, and `.envrc` files, extensionless git
hooks, install scripts, setup scripts, release scripts, migration
scripts, CI command scripts, Makefile recipes that shell out, and
documentation examples that users are expected to run.

If the target is not shell or command automation, say that this skill is
not the right audit lens and switch to a more appropriate review.

## Audit Areas

Focus on issues that can cause incorrect writes, data loss, misleading
success, hard-to-debug failures, or cross-platform breakage.

### Destructive Actions

- Unprotected `rm`, `mv`, `cp`, `ln`, `chmod`, `chown`, and recursive
  operations.
- Force modes that do not clearly limit what can be replaced.
- Deletes or overwrites that can escape the intended target directory.
- Cleanup traps that can remove user files after partial initialization.

### Quoting and Expansion

- Unquoted variables that can split paths or expand globs.
- Unsafe command substitution in paths or arguments.
- Word splitting in loops over command output.
- Globs that behave incorrectly when no file matches.
- Arrays used in shells that may not support them.
- `eval`, indirect expansion, or shell-built command strings fed by
  variables.
- `set -e` assumptions that fail in conditionals, pipelines, subshells,
  command substitutions, or cleanup paths.

### Paths and Symlinks

- Relative paths resolved from the wrong working directory.
- Symlink targets that are not normalized before comparison.
- Broken symlinks treated as missing files when that changes behavior.
- Path traversal through user-controlled inputs.
- Machine-specific paths written to tracked files.
- Confusion between repository paths, current working directory, script
  directory, and user-provided target directories.
- Unsafe writes outside the repository, home directory, or configured
  target root.

### Dry Run, Status, and Idempotency

- Dry-run output that differs from real install behavior.
- Status checks that miss stale, broken, or partially applied state.
- Repeated runs that duplicate entries or produce different results.
- Counters or summaries that do not match actual actions.
- Success messages printed after skipped or failed work.

### Backups and Recovery

- Backups that overwrite earlier backups.
- Backup paths that can escape the intended backup root.
- Partial backup sequences that lose the original file on failure.
- Missing restore guidance for risky operations.
- Backup behavior that differs between files, directories, and symlinks.

### Temporary Files and Cleanup

- Predictable temporary names.
- Missing cleanup for temporary files or lock files.
- Cleanup traps that run before variables are initialized.
- Races around `test` followed by writes.
- Writes that are not atomic when interruption matters.
- Temporary directories created without restrictive permissions when they
  may contain private data.

### Dependency and Environment Checks

- Commands used before availability checks.
- Assumptions about git identity, repository state, shell, home
  directory, permissions, locale, or terminal support.
- Environment variables used without safe defaults.
- Hidden network, package manager, or privileged command dependencies.
- Commands that behave differently when aliases, shell options, or local
  config are present.

### Portability

- Bash features used without a Bash shebang.
- Bash-version assumptions.
- GNU/BSD differences in `sed`, `find`, `readlink`, `realpath`, `date`,
  `xargs`, `mktemp`, and `grep`.
- Executable-bit and line-ending assumptions.
- Behavior that differs on macOS, Linux, WSL, or minimal containers.

### User Output and Errors

- Warnings that do not explain the consequence or next step.
- Errors that hide the failing path or command.
- Output that overstates what changed.
- Prompts that are ambiguous about destructive behavior.
- Logs that reveal secrets or machine-local private paths.

## Review Process

1. Identify the automation surfaces in scope.
2. Read the relevant files before forming findings.
3. Trace write paths, cleanup paths, dry-run paths, and force paths.
4. Check repeated-run behavior mentally or with safe smoke tests when
   practical.
5. Use static analysis tools such as `shellcheck` when available and
   relevant, but do not treat tool output as authoritative. Confirm each
   finding against the script's behavior.
6. Report only issues that could affect correctness, safety,
   portability, or user trust.

Do not spend findings on style, formatting, naming, or personal shell
preferences unless they create a concrete failure mode.

Do not run scripts or commands that can modify user files, install
software, remove files, change git state, alter permissions, contact the
network, or require elevated privileges unless the user explicitly asked
for that execution. Prefer `--help`, `--status`, `--dry-run`, smoke tests
that use temporary directories, and static inspection.

## Finding Standard

Each finding must include:

- The condition that triggers the issue.
- The realistic consequence.
- The specific code path or command involved.
- A concrete fix or mitigation.

Suppress a concern when it is only theoretical, requires impossible input,
is already guarded by surrounding code, or is a style preference without a
failure mode. If a risk depends on platform behavior that was not tested,
label it as a portability risk rather than asserting it always fails.

For documentation examples and generated snippets, cite the source
document and line when possible. If a precise line is unavailable, name
the section or command block and explain the limitation.

## Output Format

Lead with findings grouped by severity (Critical, High, Medium, Low),
one bullet per finding:

`path:line - Issue. Suggested fix.`

- **Critical:** Likely data loss, unsafe deletion, credential exposure, or
  command execution from realistic input.
- **High:** Incorrect writes, broken recovery, path escape, or misleading
  success under common conditions.
- **Medium:** Idempotency, portability, dry-run, or error handling problem
  that can break normal users.
- **Low:** Minor robustness, clarity, or edge-case issue with limited
  impact.

After findings, include:

- A short summary of the audited surfaces.
- Tests or commands run, if any.
- Residual risk, especially target-platform behavior that was not tested.

If no issues are found, say that clearly and still state what was audited
and what was not verified.
