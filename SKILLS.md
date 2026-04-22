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

### `docs-audit`

Audits documentation against actual project files, scripts, commands,
options, examples, managed paths, and generated behavior for factual
accuracy.

Use this skill when verifying README files, setup instructions, CLI
examples, managed path lists, skill catalogs, rule references, changelog
guidance, or other docs against repository reality.

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
