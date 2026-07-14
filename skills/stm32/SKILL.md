---
name: stm32
description: Operate and maintain STM32 firmware projects and toolchains with STM32Cube HAL as the normal driver layer and LL support when deliberately selected. Use when creating, inspecting, configuring, generating, building, sizing, programming, debugging, researching, or troubleshooting projects that use STM32CubeMX .ioc files, STM32CubeIDE, STM32CubeCLT, STM32Cube MCU packages, CMSIS, HAL, LL, GNU Arm Embedded tools, STM32CubeProgrammer, ST-LINK, OpenOCD, SWD, JTAG, or ROM bootloaders.
when_to_use: Use for STM32 project setup, code generation, package and toolchain selection, builds, artifacts, programming, debugging, device configuration, and failures.
argument-hint: "[project|device|board|probe|command|error]"
---

# STM32 Operations

Operate STM32 projects against their exact MCU, board, core topology, memory
map, firmware package, toolchain, repository policy, and connected hardware.
Verify version-sensitive behavior from installed tools and device documentation.

## Select the Target

Determine the requested project or operation:

- No path: locate the project root from the current directory.
- Project path: inspect repository instructions and build entry points.
- Device or board: identify the exact MCU ordering code, package, board
  revision, core or cores, flash/RAM layout, and probe interfaces.
- Error or log: reproduce the exact failing command when safe.
- Hardware operation: identify the board, MCU, probe serial number or
  bootloader connection, interface, and requested action.

Recognize STM32 projects from evidence such as an `.ioc` file, STM32CubeIDE
metadata, STM32 family startup and system files, Cube HAL/LL or CMSIS device
paths, STM32 linker scripts, or programmer/debug configurations. Do not infer
the exact MCU from `STM32` alone.

Read [references/project-layout.md](references/project-layout.md) for generated
ownership, package inputs, startup, linker, and artifact layout.

## Establish the Environment

1. Read the repository's documented generation, build, and programming flow.
2. Determine whether it uses STM32CubeMX, STM32CubeIDE, STM32CubeCLT, CMake,
   Make, another IDE, or a hand-maintained CMSIS project.
3. Verify compiler, Binutils, GDB, build system, Cube tools, MCU firmware
   package, CMSIS, HAL/LL, middleware, programmer, OpenOCD, and probe versions
   used by the project.
4. Confirm that the selected device, package, startup file, linker script, and
   programmer configuration agree.
5. Record exact versions and target identifiers with results.

Do not silently regenerate a project, update a Cube package, mix family packs,
or substitute a host tool for the repository's pinned environment.

Use HAL as the default driver model for application and generated code. Use LL
only where the project already selects it or the user deliberately chooses it
for a supported peripheral, performance, timing, code-size, or control reason.
Do not convert HAL code to LL as incidental cleanup.

## Research and Resolve Questions

Use [references/research.md](references/research.md) when answering HAL, LL,
CMSIS, register, Cube tool, programmer, debugger, diagnostic, or device-behavior
questions. Match every answer to the exact MCU, Cube package, and installed tool
versions. Prefer project inputs, installed package headers/source and examples,
live tool help, exact-device reference material and errata, then primary online
documentation. Clearly label inferences and cite sources when browsing.

## Plan the Operation

Read [references/operations.md](references/operations.md) for generation,
build, programming, debug, and verification guidance. Check live tool help
before using CubeProgrammer, CubeMX, OpenOCD, or IDE command-line flags.

Keep these boundaries explicit:

- Treat the `.ioc` file and generator settings as maintained inputs only when
  the repository establishes CubeMX ownership.
- Classify generated and maintained code before editing or regenerating.
- Verify startup, vector table, system clock, linker script, bootloader offset,
  and memory regions against the exact MCU and build configuration.
- Read and preserve device memory and option-byte state before an operation
  that can replace, protect, or irreversibly change it. Verify the backup.
- Do not broaden a build request into generation, programming, reset, monitor,
  option-byte access, mass erase, or debug-probe control.

## Execute and Verify

For generation and builds:

1. Confirm device, board, core, firmware package, toolchain, and configuration.
2. Back up and verify the complete project before regeneration that can
   overwrite files; inspect the generated diff afterward.
3. Run the repository's narrowest supported configure, generate, build, size,
   or test command.
4. Inspect warnings, map output, sections, startup objects, vector placement,
   and produced ELF, BIN, HEX, or other artifacts.
5. Verify flash and RAM placement, stack/heap, bootloader/application boundary,
   load addresses, and image fit.

For target access:

1. Require an explicit request for programming, erase, reset, ROM bootloader,
   SWD/JTAG, GDB, option-byte, OTP, or security operations.
2. Refuse to guess when multiple boards, probes, interfaces, or cores are
   plausible.
3. Confirm target voltage, exact device identity, memory map, and current
   protection state before writing.
4. Program only requested regions, verify them, and separately report whether
   the image booted and whether application behavior was exercised.

Require operation-specific confirmation before mass erase, readout-protection
changes, option-byte writes, OTP writes, debug-port restrictions, TrustZone or
secure-state transitions, boot-address changes, or operations that can make
memory unreadable or the device inaccessible.

## Diagnose Failures

Use the `debug` skill for live failures and the STM32-specific checks in
[references/troubleshooting.md](references/troubleshooting.md). Preserve the
matching ELF, map, binaries, `.ioc`, linker script, build log, fault output,
device-state reads, and programmer/debugger logs.

## Route Related Work

- Use `firmware-review` for interrupts, DMA/cache, RTOS, registers, clocks,
  startup, linker, multicore, or protocol correctness.
- Use `security-audit` for option bytes, readout protection, TrustZone, secure
  boot, OTP, update trust, debug exposure, or secret provisioning.
- Use `dependency-audit` for Cube packages, CMSIS, HAL/LL, middleware, RTOS,
  packs, or vendored drivers.
- Use `script-audit` for generation, build, programmer, OpenOCD, or production
  automation.
- Use `test-audit` for host, simulator, target, and hardware coverage.

## Report Results

State the project path, exact MCU and board/core, toolchain and Cube package,
generation inputs, probe and interface, commands run, artifacts and sizes,
memory regions written, option/security state touched, verification result,
observed boot behavior, unperformed hardware checks, and remaining risk.
