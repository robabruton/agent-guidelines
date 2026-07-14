# AVR Project Layout

Direct AVR C projects commonly use Make or CMake around AVR GCC, AVR-LibC,
Binutils, and a programmer utility. Treat the repository's documented entry
point as authoritative and do not convert its build system without a request.

## Make and CMake Projects

Inspect:

- Exact `-mmcu` selection and any architecture-specific flags.
- `F_CPU` or equivalent clock-frequency definition.
- Source, include, assembly, linker, library, and linker-script inputs.
- Optimization, LTO, section placement, garbage collection, and debug flags.
- ELF-to-HEX and EEPROM-image conversion steps.
- Programmer targets and their part, interface, port, and bit-clock settings.

Keep device selection in one maintained build input. Do not let compile,
link, size, disassembly, and programming commands name different devices.

## Toolchain Device Support

Inspect the compiler's device specifications, headers, startup and library
selection, AVR-LibC version, and programmer part database. A compiler accepting
an `-mmcu` value does not prove that a separately installed programmer utility
uses the same part name or supports the same memories and interface.

## Maintained and Generated State

Classify before editing:

- Maintained source, headers, assembly, linker scripts, Make/CMake files, and
  programmer configuration.
- Generated dependency files, objects, ELF, HEX, EEPROM images, maps,
  listings, disassembly, and IDE build directories.
- Toolchain device-support files managed outside the repository.
- Bootloader, fuse, lock-bit, and EEPROM images that are maintained inputs even
  though they are later written to a device.

Preserve build artifacts with matching source and configuration when they are
needed for field diagnosis or reproducible programming.

## Device Documentation

Use the exact device datasheet, silicon errata, instruction-set documentation,
toolchain release notes, and programmer documentation. Verify memory maps, vector
tables, fuse polarity and defaults, clock startup, programming voltage,
interface pin use, and signature bytes from those sources rather than from a
nearby family member.
