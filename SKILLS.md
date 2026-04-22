# Skills

Skills live in `skills/` as reusable agent workflows. Each skill should
cover a concrete workflow that benefits from named, repeatable
instructions rather than restating the project rules.

## Metadata Policy

Skill frontmatter should use portable Agent Skills fields plus a small
approved subset of Claude Code fields that improve invocation:

- `name`
- `description`
- `when_to_use`
- `argument-hint`

Avoid behavior-changing Claude Code fields such as `model`, `effort`,
`context`, `agent`, `hooks`, and `shell` unless a future change has a
specific need for them. Use `allowed-tools` only for low-risk read/search
tools on audit and review skills; it pre-approves those tools in Claude
Code but does not deny other tools.

## Current Skills

### `code-review`

Reviews code, local changes, branches, files, functions, classes, or
small projects for correctness, maintainability, edge cases, and
integration risk.

Use this skill when the user asks for a general code review, quality
check, bug hunt, pre-commit review, branch review, or review of local
software work.

### `dependency-audit`

Audits dependency additions, updates, removals, manifests, and lockfiles
for necessity, security, maintenance, licensing, and supply-chain risk.

Use this skill when adding, updating, removing, or questioning
dependencies, package manifests, lockfiles, vendored code, generated
clients, or third-party assets.

### `docstrings`

Adds or updates language-appropriate documentation comments for public
symbols and non-trivial code while preserving accurate existing docs.

Use this skill when adding or updating docstrings for files,
directories, changed code, public APIs, structs, enums, callbacks,
macros, or non-trivial source symbols.

### `docs-audit`

Audits documentation against actual project files, scripts, commands,
options, examples, managed paths, and generated behavior for factual
accuracy.

Use this skill when verifying README files, setup instructions, CLI
examples, managed path lists, skill catalogs, rule references, changelog
guidance, or other docs against repository reality.

### `docs-review`

Reviews documentation as writing for reader clarity, structure, tone,
grammar, style, completeness, and task flow.

Use this skill when reviewing README files, guides, rules, skill docs,
setup instructions, or other documentation for reader success rather than
factual verification against project behavior.

### `explain`

Explains code, files, workflows, commands, or project concepts clearly
without editing files or turning the response into a review.

Use this skill when the user asks to understand a file, function,
command, workflow, architecture, data flow, branch, error path, or
project concept.

### `firmware-review`

Reviews embedded firmware, drivers, RTOS code, ISRs,
hardware-facing C/C++, startup code, linker assumptions, and device
protocols for correctness, timing, concurrency, and hardware-integration
issues.

Use this skill when reviewing firmware or hardware-facing code where
target behavior, interrupts, registers, DMA, cache, timing, RTOS
interactions, or board configuration may affect correctness.

### `project-setup`

Initializes or updates a repository with shared project rules, git hooks,
commit standards, local excludes, changelog setup, and agent instruction
files.

Use this skill for new repositories and existing repositories that need
the project standards applied or refreshed. The workflow is intended to be
safe to rerun.

### `script-audit`

Audits shell scripts, git hooks, installers, setup workflows, and command
automation for safety, correctness, portability, and idempotency.

Use this skill when reviewing automation that creates, modifies, links,
moves, removes, backs up, or reports on files and project state.

### `security-audit`

Audits code, configuration, dependencies, scripts, firmware security
surfaces, and system design for exploitable security vulnerabilities
based on the actual attack surface.

Use this skill when reviewing authentication, authorization, secrets,
cryptography, dependency risk, deployment exposure, input trust
boundaries, or firmware security concerns.

### `test-audit`

Audits tests for meaningful behavioral coverage, weak assertions,
missing edge cases, brittle test dependencies, and focused opportunities
to add or improve tests.

Use this skill when reviewing tests, checking whether branch behavior is
covered, improving coverage, adding regression tests, or deciding which
tests are missing.
