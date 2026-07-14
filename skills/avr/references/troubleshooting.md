# AVR Troubleshooting

Start with the exact failing command and first actionable diagnostic. Record
the device, clock, toolchain, pack, programmer, interface, power arrangement,
and current accessible configuration.

## Build and Link

Check for:

- Compile and link commands naming different MCUs.
- Wrong architecture, ABI, startup object, linker script, or device pack.
- `F_CPU` differing from the physical clock or fuse configuration.
- Missing AVR-LibC or XC8 device support.
- LTO or section-garbage-collection removing required interrupt or startup code.
- Flash, SRAM, EEPROM, vector, or bootloader overflow.
- Program-memory access using the wrong address space or accessor.

Use the matching map, ELF, disassembly, and device memory map before changing
optimization or memory layout.

## Programmer Connection

Check programmer identity and firmware, target voltage and ground, cable and
pin orientation, reset behavior, interface selection, host permissions, and
whether another process owns the tool. Confirm the device supports the chosen
interface and that the interface remains enabled by current configuration.

For signature mismatch, resolve part identity, wiring, power, interface, and
programming clock before considering an override. Do not bypass signature
checking merely to force a write.

## Clock and Programming Speed

ISP programming clock must be compatible with the target clock. A device with
unexpected clock fuses, a divided clock, an absent crystal, or no valid clock
can appear unresponsive. Reduce programming speed only with a reason and verify
the actual clock source. Establish whether external clock injection or another
recovery mode is required.

## UPDI, PDI, JTAG, and debugWIRE

Check interface-specific pins, pull-ups, voltage levels, activation sequences,
reset configuration, prior debug-session teardown, and programmer support.
Do not alter fuses or apply high voltage until the exact interface state and
recovery consequences are understood.

## Programmed but Not Running

Check reset cause, clock source and startup time, brownout settings, watchdog,
vector location, boot reset selection, bootloader/application boundary, stack,
GPIO alternate use, and power integrity. Capture observable startup output or
pin behavior rather than inferring execution from successful verification.

## Runtime Faults

AVR targets may lack rich fault records. Preserve reset-cause registers early,
watchdog state, stack high-water evidence, SRAM usage, interrupt state, and
reproducible external stimuli. Use the matching ELF and disassembly to trace
corruption, invalid jumps, stack exhaustion, and interrupt-vector problems.

## Reporting

Separate confirmed cause from hypotheses. Include the first relevant error,
exact tools and versions, device and interface, state reads, changes made,
verification result, observed runtime evidence, and any destructive recovery
step not performed.
