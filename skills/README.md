# Skills

Skills live in `skills/` as reusable agent workflows. Each skill should
cover a concrete workflow that benefits from named, repeatable
instructions rather than restating the project rules.

## Metadata Policy

The [Agent Skills specification](https://agentskills.io/specification)
defines `name` and `description` as required portable fields. It also defines
optional `license`, `compatibility`, and `metadata` fields plus experimental
`allowed-tools`. This repository requires every `description` to state both
what the skill does and when it applies because consumers load that field
eagerly for routing. Keep it concise to limit startup context.

The skills also retain the Claude Code extensions `when_to_use` and
`argument-hint`, documented in the
[Claude Code skill reference](https://code.claude.com/docs/en/slash-commands).
Claude appends `when_to_use` to its skill listing and displays
`argument-hint` during invocation; other consumers may ignore both. Put every
essential cross-harness trigger in `description`, not only in an extension.

Use `allowed-tools` only for low-risk read/search tools on audit and review
skills. Support is experimental across Agent Skills consumers; in Claude Code
it pre-approves those tools but does not deny other tools. Avoid
behavior-changing Claude extensions such as `model`, `effort`, `context`,
`agent`, `hooks`, and `shell` without a specific current requirement.

## Current Skills

### `agent-memory`

Maintains a durable, file-based memory store across sessions — deciding
what is worth remembering, writing typed point-in-time entries, keeping a
lean router index, organizing into hierarchical load tiers that scale
without bloating context, and recalling the right entries for a task. It
ships starter templates and a read-only report script.

Use this skill when the user asks you to remember or save something, when
a decision or correction is settled that would be costly to rediscover, at
session start to recall what is relevant, at session end to record handoff
state, or when the memory store has grown large enough to need
reorganizing.

### `avr`

Operates and maintains 8-bit AVR projects and toolchains, including exact
device and interface selection, project configuration, builds, artifacts,
programming, debugging, device-state preservation, and recovery-aware
troubleshooting.

Use this skill for ATmega, ATtiny, AVR Dx/Ex, megaAVR, tinyAVR, or XMEGA
projects that use AVR GCC, AVR-LibC, Make or CMake, avrdude, UPDI, ISP,
PDI, JTAG, or debugWIRE.

### `code-review`

Reviews code, local changes, branches, files, functions, classes, or
small projects for correctness, maintainability, edge cases, and
integration risk.

Use this skill when the user asks for a general code review, quality
check, bug hunt, pre-commit review, branch review, or review of local
software work.

### `debug`

Drives a live failure to a verified root-cause fix: reproduce the
failure, isolate it systematically, diagnose the cause, fix it at its
origin, and land the regression test in the same branch.

Use this skill when something concretely misbehaves — a failing test,
an error message, a crash, a wrong result, or a regression — and the
goal is a fix rather than a review of code at rest.

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

### `esp-idf`

Operates and maintains ESP-IDF projects and local toolchains, including
environment selection, project configuration, components, builds, tests,
artifacts, flashing, monitoring, version-matched API and tool research, and
troubleshooting.

Use this skill when creating, inspecting, configuring, building, testing,
flashing, monitoring, researching, or troubleshooting projects that use
ESP-IDF tooling, components, configuration, partition tables, or EIM-managed
installations.

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

### `stm32`

Operates and maintains STM32 projects and toolchains, including HAL-first
Cube code generation, package and target selection, builds, memory
artifacts, programming, debugging, option-byte safety, API research, and
target troubleshooting.

Use this skill for projects that use STM32CubeMX, STM32CubeIDE,
STM32CubeCLT, STM32Cube MCU packages, CMSIS, HAL, LL, GNU Arm tools,
STM32CubeProgrammer, ST-LINK, OpenOCD, SWD, JTAG, or ROM bootloaders.

### `test-audit`

Audits tests for meaningful behavioral coverage, weak assertions,
missing edge cases, brittle test dependencies, and focused opportunities
to add or improve tests.

Use this skill when reviewing tests, checking whether branch behavior is
covered, improving coverage, adding regression tests, or deciding which
tests are missing.
