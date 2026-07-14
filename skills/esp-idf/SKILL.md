---
name: esp-idf
description: Operate and maintain ESP-IDF projects and local toolchains. Use when creating, inspecting, configuring, building, testing, flashing, monitoring, or troubleshooting projects that use idf.py, project.cmake, idf_component_register, sdkconfig, Kconfig, ESP-IDF component manifests, partition tables, esptool, OpenOCD, or EIM-managed installations.
when_to_use: Use for ESP-IDF project setup, component work, configuration, builds, tests, artifacts, hardware operations, and toolchain failures.
argument-hint: "[project|component|target|command|error]"
---

# ESP-IDF Operations

Operate ESP-IDF projects against their actual framework, target, repository
policy, and connected hardware. Verify version-sensitive commands from the
active installation instead of relying on remembered syntax.

## Select the Target

Determine the requested project or operation before changing anything:

- No path: locate the project root from the current directory.
- Project path: inspect that project and its repository instructions.
- Component: locate its registration, manifest, configuration, and callers.
- Error or log: reproduce the exact failing command when safe.
- Hardware operation: identify the board, chip target, serial port or probe,
  and requested action.

Recognize an ESP-IDF project from evidence such as a top-level
`CMakeLists.txt` that includes `project.cmake`, component registrations,
`sdkconfig` files, or an `idf_component.yml` manifest. Do not classify a
generic CMake or embedded project as ESP-IDF from its language alone.

Read the project instructions and relevant files before choosing a version,
target, configuration, or command. For project-layout and ownership details,
read [references/project-layout.md](references/project-layout.md).

## Establish the Environment

1. Inspect the repository for a documented activation command, container,
   version file, or wrapper.
2. Prefer that explicit mechanism. Support EIM, export scripts, and other
   managers without making one manager or filesystem layout universal.
3. If no mechanism is documented, inspect available installations and ask
   before selecting among materially different versions.
4. Verify the active environment with `idf.py --version`, `IDF_PATH`,
   `IDF_TOOLS_PATH`, the Python environment, and the relevant compiler.
5. Record the exact ESP-IDF release or commit and target used for results.

Honor configured tool paths. Do not assume tools live under `~/.espressif`,
silently select the newest installation, install or update a framework, or
switch a project's version without authorization. Treat remembered versions,
flags, release status, and paths as point-in-time knowledge.

## Plan the Operation

Use the smallest operation that establishes the requested result. Read
[references/operations.md](references/operations.md) for command selection,
side effects, artifact checks, and hardware gates. Check `idf.py --help` and
command-specific help in the active version before using unfamiliar or
version-sensitive flags.

Keep these boundaries explicit:

- Use `sdkconfig.defaults` or the repository's established configuration
  inputs for reproducible defaults; do not casually hand-edit generated
  configuration.
- Treat `components/` as optional. Add it when a real local component exists,
  not as an empty convention.
- Modify local component sources and manifests, never generated
  `managed_components/` contents.
- Inspect and preserve the complete target before commands that replace
  configuration, remove build state, overwrite flash, or otherwise destroy
  data. Verify the backup before proceeding when preservation is applicable.
- Do not broaden a build request into flashing, reset, monitoring, JTAG, or
  other target access.

## Execute and Verify

For configuration and builds:

1. Confirm the framework version and chip target.
2. Inspect current configuration, component, dependency, and partition inputs.
3. Run the narrowest applicable configure, build, size, or test command.
4. Read the complete command result; warnings can reveal target, partition,
   deprecation, or configuration problems even when the command succeeds.
5. Verify the expected ELF, binary, map, bootloader, partition-table, size, or
   test output rather than inferring success from the exit code alone.

For target access:

1. Require an explicit request for flash, erase, reset, monitor, JTAG, or
   OpenOCD operations.
2. Identify the exact device and refuse to guess when multiple ports or probes
   are plausible.
3. Confirm that the configured target matches the board.
4. Report the command output and observed boot or monitor behavior. A
   successful build or flash does not prove that the application works.

Require operation-specific confirmation for flash erasure, eFuse writes,
secure-boot key changes, flash-encryption state changes, or other irreversible
device state. Preserve flash or device data first when feasible and relevant.

## Diagnose Failures

Use the `debug` skill for a live failure and add the ESP-IDF-specific checks in
[references/troubleshooting.md](references/troubleshooting.md). Reproduce the
exact failure, change one relevant variable at a time, and fix the cause rather
than masking diagnostics with cleanup or configuration resets.

Preserve matching ELF, map, configuration, partition, flash, and serial-log
artifacts needed to understand a target-only failure. Decode a panic or
backtrace only with artifacts from the same firmware build.

## Route Related Work

- Use `firmware-review` for ISR, RTOS, DMA, register, timing, memory, startup,
  linker, or hardware-protocol correctness review.
- Use `security-audit` for secure boot, flash encryption, eFuses, keys, OTA
  trust, rollback protection, or exposed debug interfaces.
- Use `dependency-audit` for managed-component or third-party dependency
  changes.
- Use `script-audit` for EIM wrappers, installers, shell helpers, build
  automation, or destructive command snippets.
- Use `test-audit` when assessing whether firmware behavior has meaningful
  automated or hardware coverage.

Use more than one skill when the task crosses these boundaries; ESP-IDF
context does not replace the specialized review or audit workflow.

## Report Results

State:

- Project path, ESP-IDF version or commit, and chip target.
- Environment or activation mechanism used.
- Configuration inputs and commands run.
- Artifacts, sizes, tests, flash results, and observed target behavior.
- Hardware operations not performed and checks that could not be verified.
- Remaining risk, especially when no matching board was exercised.
