---
name: avr
description: Operate and maintain 8-bit Microchip AVR firmware projects and toolchains. Use when creating, inspecting, configuring, building, sizing, programming, debugging, or troubleshooting ATmega, ATtiny, AVR Dx/Ex, megaAVR, tinyAVR, or XMEGA projects that use AVR GCC, AVR-LibC, MPLAB XC8, MPLAB X, Device Family Packs, avrdude, UPDI, ISP, PDI, JTAG, or debugWIRE.
when_to_use: Use for 8-bit AVR project setup, device and toolchain selection, builds, artifacts, programming, debugging, device configuration, and failures.
argument-hint: "[project|device|programmer|command|error]"
---

# AVR Operations

Operate 8-bit AVR projects against their exact device, clock, toolchain,
programmer, repository policy, and connected hardware. Verify commands and
device support from the installed tools and selected device documentation.

Do not extend this skill to PIC, SAM, AVR32, or unrelated Arduino targets.
Use the project evidence and exact part number rather than treating all AVR
devices as interchangeable.

## Select the Target

Determine the requested project or operation:

- No path: locate the project root from the current directory.
- Project path: inspect its repository instructions and build entry point.
- Device: identify the complete ordering code, family, memory sizes, voltage,
  clock source, and programming/debug interfaces.
- Error or log: reproduce the exact failing command when safe.
- Hardware operation: identify the target, programmer/debugger, interface,
  port or serial number, power arrangement, and requested action.

Recognize AVR projects from evidence such as `-mmcu` build flags, AVR headers,
MPLAB X project metadata, AVR-specific PlatformIO or Arduino configuration, or
programming commands naming an AVR part. Do not infer the device from a generic
C file or board nickname.

Read [references/project-layout.md](references/project-layout.md) for project
forms, maintained inputs, generated files, and artifact ownership.

## Establish the Environment

1. Read the repository's documented build and programming workflow.
2. Determine whether it uses AVR GCC, MPLAB XC8, an IDE-generated build,
   Arduino, PlatformIO, or another explicit environment.
3. Verify compiler, Binutils, C library, Device Family Pack, build tool,
   programmer utility, and debugger versions from live commands and project
   metadata.
4. Confirm that the selected toolchain and pack support the exact device.
5. Record the device, toolchain, pack, programmer, and interface used.

Do not silently substitute XC8 for AVR GCC, a system `avrdude` for a
framework-bundled build, or a newer Device Family Pack for a pinned project.
Recognize existing Microchip Studio projects without selecting that environment
for new work unless the user requests it.

## Plan the Operation

Read [references/operations.md](references/operations.md) for build,
inspection, programming, debug, and verification guidance. Check the active
tool's help before using version-sensitive flags or programmer identifiers.

Keep these boundaries explicit:

- Treat the exact MCU and programmer interface as required inputs.
- Preserve build flags that control device, clock, ABI, optimization, section
  garbage collection, and memory placement.
- Distinguish flash, EEPROM, user row, fuses, lock bits, bootloader, and
  signature/calibration regions.
- Read and preserve all accessible device state before an operation that can
  replace or irreversibly protect it. Verify the backup before writing.
- Do not broaden a build request into programming, reset, fuse access, erase,
  or debug-probe control.

## Execute and Verify

For builds:

1. Confirm device, `F_CPU` or equivalent clock assumptions, toolchain, and
   maintained build configuration.
2. Run the repository's narrowest supported configure, build, size, or test
   command.
3. Inspect warnings, map output, section sizes, interrupt vectors, startup
   objects, and produced ELF, HEX, EEPROM, or binary artifacts.
4. Verify flash, SRAM, EEPROM, bootloader, and vector placement against the
   exact device and linker configuration.

For target access:

1. Require an explicit request for programming, erase, reset, debug, fuse,
   lock-bit, EEPROM, or bootloader operations.
2. Refuse to guess when multiple devices, programmers, ports, or interfaces
   are plausible.
3. Read the device signature and current accessible configuration before
   writing when the tool and interface support it.
4. Program only the requested regions, verify them, and separately report
   whether the firmware booted and whether its behavior was exercised.

Require operation-specific confirmation before chip erase, fuse or lock-bit
writes, reset-pin repurposing, debug-interface disabling, clock-source changes,
read protection, bootloader replacement, or writes that can require external
clocking or high-voltage recovery.

## Diagnose Failures

Use the `debug` skill for live failures and the AVR-specific checks in
[references/troubleshooting.md](references/troubleshooting.md). Preserve the
matching ELF, map, HEX, EEPROM image, build log, device-state reads, and
programmer output. Change one relevant variable at a time.

## Route Related Work

- Use `firmware-review` for interrupt, register, timing, memory, startup,
  protocol, or concurrency correctness.
- Use `security-audit` for lock bits, bootloaders, protected memory, debug
  access, update trust, or secret provisioning.
- Use `dependency-audit` for frameworks, device packs, libraries, cores, or
  vendored drivers.
- Use `script-audit` for Make targets, programming helpers, installers, or
  production command automation.
- Use `test-audit` for simulator, host, target, and hardware coverage.

## Report Results

State the project path, exact AVR device, clock assumptions, toolchain and pack,
programmer and interface, commands run, artifacts and sizes, memory regions
written, verification result, observed boot behavior, unperformed hardware
checks, and remaining recovery or compatibility risk.
