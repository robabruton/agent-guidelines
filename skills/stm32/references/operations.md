# STM32 Operations

Verify syntax against the installed tools. Cube, IDE, OpenOCD, and programmer
commands and identifiers can change across releases.

## Inspect the Environment

- Use live version output for `arm-none-eabi-gcc`, Binutils, GDB, CMake, Ninja
  or Make, STM32Cube tools, OpenOCD, and programmer utilities as applicable.
- Identify the STM32Cube MCU package, CMSIS, HAL/LL, middleware, RTOS, and board
  support versions from project inputs and package metadata.
- Confirm exact MCU, core, CPU/FPU/float ABI, startup file, linker script, and
  debugger target configuration.

Do not combine the compiler from one bundle with unverified debugger or
programmer components from another.

## Generate Code

- Regenerate only when the repository identifies CubeMX or another generator
  as authoritative and the requested change requires it.
- Use the project's recorded generator and package versions.
- Back up and verify the entire project before generation that overwrites
  files.
- Review device, pins, clocks, DMA, interrupts, middleware, project settings,
  generated source, libraries, startup, linker, and build metadata afterward.
- Reject unrelated generator churn rather than hiding it among application
  changes.

## Build and Inspect

- Run the repository's documented CMake, Make, IDE, or wrapper command.
- Verify compiler and linker architecture flags agree.
- Inspect ELF sections, symbols, map, disassembly, and size output with matching
  GNU Arm tools.
- Confirm vector, code, data, stack, heap, retained, DMA, external-memory,
  bootloader, and application placement.
- Produce BIN or HEX files through the maintained build so offsets and load
  addresses remain explicit.

## Identify the Target Path

Establish:

- Exact MCU, board revision, target voltage, and power source.
- ST-LINK or other probe model, serial number, firmware, and host permissions.
- SWD, JTAG, UART, USB DFU, or another supported ROM bootloader interface.
- Reset and boot-pin state.
- Target core and access port for multicore devices.
- Current readout protection, write protection, TrustZone, and relevant option
  bytes.

Use read-only connection and identification first. Do not probe multiple boards
by resetting, erasing, or programming them.

## Preserve and Program

When accessible and relevant, back up and verify internal and external flash,
configuration storage, calibration or serial data, OTP, and option bytes.
Protected memory may be unreadable; report that before an erase or protection
transition.

Use STM32CubeProgrammer, OpenOCD, an IDE, or another documented utility with an
explicit probe/interface and address plan. Program only requested regions,
verify written data, reset only when requested or required by the documented
flow, and observe boot separately.

## Option Bytes and Security State

Decode current and proposed values for the exact MCU. Explain each changed
field, reset behavior, protection transition, erase implication, and recovery
path. Require specific confirmation for readout protection, write protection,
boot addresses, watchdog modes, bank configuration, TrustZone, secure state,
debug restrictions, or OTP.

Do not assume protection levels can be reversed without mass erase or that all
security transitions are reversible.

## Debug

Use the matching ELF and source. Confirm probe, target script, core, reset
strategy, interface speed, optimization, and security access. Account for
hardware breakpoint/watchpoint limits, low-power modes, watchdogs, multicore
coordination, flash breakpoints, and code running from external memory.
