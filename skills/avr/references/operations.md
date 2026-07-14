# AVR Operations

Verify syntax against the installed tool and exact device. Commands below name
common tools and operations without defining a universal project workflow.

## Inspect the Toolchain

- Use compiler version output such as `avr-gcc --version` or
  `xc8-cc --version` as applicable.
- Inspect assembler, linker, object-copy, size, and C-library versions used by
  the actual build.
- Inspect the selected Device Family Pack and framework/core package versions.
- Use `avrdude --help`, MPLAB tool help, or the repository's programmer wrapper
  to discover supported flags and identifiers.

Do not mix host-installed and framework-bundled tools unless the project makes
that composition explicit.

## Build and Inspect

- Run the repository's documented build target.
- Verify the compiler and linker receive the same device selection.
- Inspect ELF sections and symbols with the matching AVR Binutils tools.
- Use the build's size command to assess flash, SRAM, EEPROM, and bootloader
  limits.
- Generate HEX, EEPROM, binary, listing, or disassembly output through the
  maintained build rather than an ad hoc conversion with different flags.
- Preserve the ELF and map alongside programmed images for diagnosis.

## Identify the Programmer Path

Establish:

- Exact MCU part and signature.
- Programmer/debugger model, serial number, firmware, and host permissions.
- ISP, UPDI, PDI, JTAG, debugWIRE, or bootloader interface.
- Target power source and voltage.
- Reset, clock, and programming pins.
- Interface clock or bit-clock constraints.

Use a read-only identification or no-write mode when available before any
programming command. Do not probe multiple connected targets by erasing,
resetting, or writing them.

## Preserve Device State

When accessible and relevant, read and verify backups of:

- Flash and bootloader regions.
- EEPROM and user row.
- Fuses and configuration bytes.
- Lock bits and protection state.
- Calibration or serial data not reproducible from source.

Some protected state cannot be read back. Report that limitation before an
operation that could destroy it.

## Program and Verify

- Name the exact part, programmer, interface, and port explicitly.
- Write only the requested memory regions.
- Keep erase behavior explicit; some programming operations imply erase.
- Verify written data through the same tool or an independent readback when
  supported.
- Distinguish programmer verification, firmware boot, and application behavior.

Never treat a successful HEX write as proof that oscillator, brownout, reset,
bootloader, interrupt, or application configuration is correct.

## Fuses, Lock Bits, and Recovery

Decode current and proposed values against the exact datasheet before writing.
Explain each changed field and its consequences. Require specific confirmation
for clock-source changes, reset-pin changes, debug-interface changes, memory
protection, boot-size changes, or lock bits.

Establish the recovery path first. Depending on the device and change, recovery
can require an external clock, UPDI activation sequence, chip erase, or
high-voltage programming and may destroy protected contents.

## Debug

Confirm that the exact device and probe support the requested debug interface.
Preserve production fuse and lock state before enabling or disabling debug.
Use the matching ELF and source, and account for optimization, breakpoints,
watchpoint limits, interrupt behavior, and debugWIRE or interface teardown.
