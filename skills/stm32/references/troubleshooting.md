# STM32 Troubleshooting

Start with the exact failing command and first actionable diagnostic. Record
the MCU, board and core, toolchain, Cube package, build system, probe/interface,
power, option/protection state, and matching artifacts.

## Generation and Build

Check for:

- `.ioc`, generated source, package, and project metadata from different
  generator releases.
- Wrong device, CPU, FPU, float ABI, startup object, system file, or linker
  script.
- Missing or duplicated HAL/LL, CMSIS, middleware, or RTOS sources.
- Generated code overwritten outside preservation regions.
- Incorrect interrupt handler names or vector-table ownership.
- Flash/RAM overflow, orphan sections, or incorrect load/run addresses.
- Bootloader offset, vector relocation, or multicore image mismatch.

Use the matching ELF, map, linker script, disassembly, and package metadata
before changing compiler flags or memory layout.

## Probe and Programmer Connection

Check exact probe identity and firmware, target voltage, power, ground, SWD/JTAG
wiring, reset strategy, interface speed, core/access-port selection, host
permissions, and process ownership. Confirm boot and low-power state are not
preventing connection.

Use connect-under-reset or altered speed only when evidence supports it. Do not
mass erase or change option bytes merely to make a connection work.

## ROM Bootloader

Verify that the exact MCU supports the selected system-memory bootloader and
interface, then check boot pins or option bytes, reset sequence, host port,
protocol, and supported memory operations. A board's USB connector does not
guarantee DFU support or correct bootloader routing.

## Programmed but Not Running

Check reset reason, boot address, vector-table value, initial stack pointer,
clock startup, power supply and voltage scaling, brownout, watchdog, flash
latency, cache, MPU, external memory, TrustZone attribution, and bootloader
handoff. Capture SWO, UART, GPIO, or debugger evidence rather than inferring
execution from successful flash verification.

## Runtime Faults

Preserve the complete fault frame, fault-status registers, reset cause,
backtrace, task state, stack evidence, and exact ELF. Check interrupt priority,
DMA/cache coherency, alignment, stack, heap, clock, low-power, multicore, and
memory-region assumptions as indicated by the evidence.

Use `firmware-review` for implicated startup, linker, ISR, RTOS, DMA/cache,
register, clock, or protocol code.

## Protection and Option Bytes

If memory is unreadable or debug access fails, inspect protection and security
state without changing it. Establish whether recovery requires reset,
bootloader entry, regression, or mass erase and what data that destroys. Never
guess option-byte values from another STM32 family.

## Reporting

Separate verified cause from hypotheses. Include the first relevant error,
exact tools and versions, target and interface, state reads, changes made,
verification result, boot/runtime evidence, and any erase, protection, or
security operation not performed.
