# ESP-IDF Troubleshooting

Start with the exact failing command and first actionable error. Preserve the
active version, target, configuration, build log, and matching artifacts.

## Environment and Toolchain

Check for:

- `idf.py` from a different installation than `IDF_PATH`.
- A Python environment or toolchain that does not belong to the active release.
- An unexpected `IDF_TOOLS_PATH` or manager registry.
- A project requiring a different ESP-IDF release or commit.
- Missing host packages or unsupported host architecture.
- Environment activation from one shell leaking into another workflow.

Re-activate through the project's documented mechanism and verify every path.
Do not repair a mismatch by globally reinstalling or updating tools unless that
scope is requested.

## Target, CMake, and Components

Check for:

- Configured target differing from the board or compiler family.
- A component outside registered component roots.
- Incorrect source, include, or dependency declarations.
- A component manifest or lock state inconsistent with resolved dependencies.
- A moved or renamed component hidden by stale generated build state.
- CMake cache entries referring to another checkout or environment.

Prefer reconfiguration after correcting the owning input. Use a clean build only
when evidence points to stale generated state, and preserve useful diagnostics
before deletion.

## Kconfig and Configuration

Trace the symbol definition, prompt visibility, dependency expression, selected
target, defaults files, and current `sdkconfig`. Do not force a value that its
dependencies make invalid. Review configuration changes caused by switching
targets or ESP-IDF releases.

## Linking, Memory, and Partitions

For undefined symbols, verify component dependency direction, conditional
sources, configuration guards, and language linkage. For overflow or image-size
failures, inspect the linker map, size report, partition CSV, configured table,
and application binary together. Do not enlarge a partition until the intended
layout, OTA behavior, and physical flash size are established.

## Serial and Flashing

Check:

- Correct and stable device path.
- User permissions and another process holding the port.
- USB cable data capability, power, and connection stability.
- Board reset/bootloader-entry behavior.
- Baud, flash mode, frequency, size, and target assumptions.
- Whether the device changed port names after reset.

Do not cycle through multiple connected devices with flash or reset commands to
find the right one. Resolve identity first.

## Runtime Faults

Capture the complete boot and fault log, reset reason, panic type, register dump,
backtrace, firmware version, configuration, and board conditions. Decode
addresses using the exact ELF from the flashed build. Check watchdog, stack,
heap, invalid-access, cache, ISR, RTOS, and multicore context as indicated by the
fault rather than guessing from the final line alone.

Use `firmware-review` to inspect implicated ISR, RTOS, DMA, register, startup,
linker, or protocol code. Reproduce and verify the fix under the conditions that
triggered the fault.

## OpenOCD and JTAG

Verify the board/probe configuration, interface permissions, target definition,
physical wiring, power, debug-interface state, and whether security settings
disable or restrict debugging. Do not alter eFuses or security state merely to
make a debug connection work.

## Reporting

Separate verified cause from hypotheses. Include the exact failing command,
first relevant diagnostic, environment and target, changes made, verification
command, target observations, and any hardware or configuration state that
remains unverified.
