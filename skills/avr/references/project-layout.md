# AVR Project Layout

AVR projects use several unrelated build ecosystems. Treat the repository's
documented entry point as authoritative and do not convert project formats
without a separate request.

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

## MPLAB X and XC8 Projects

An MPLAB X project commonly uses a `.X` directory with `nbproject/` metadata.
Inspect the selected device, configuration, compiler, Device Family Pack,
programmer/debugger, and generated Makefiles through project metadata and live
tool output. Preserve maintained configuration and avoid editing generated
Makefiles when the IDE owns them.

Device Family Packs can provide headers, libraries, programming algorithms,
and device descriptions independently of the compiler version. Record the pack
identifier and version used for a reproducible result.

## Arduino and PlatformIO Projects

Identify the selected platform, board/core package, variant, framework,
programmer or upload protocol, bootloader, and bundled tool versions. A board
name is not a substitute for the MCU ordering code. Use the framework's own
build and upload commands unless the project explicitly exposes the underlying
toolchain.

Do not assume an Arduino bootloader is present on a bare AVR or use bootloader
upload settings for an ISP or UPDI connection.

## Maintained and Generated State

Classify before editing:

- Maintained source, headers, assembly, linker scripts, Make/CMake files, IDE
  configuration, and framework manifests.
- Generated dependency files, objects, ELF, HEX, EEPROM images, maps,
  listings, disassembly, and IDE build directories.
- Device-pack and framework caches managed outside the repository.
- Bootloader, fuse, lock-bit, and EEPROM images that are maintained inputs even
  though they are later written to a device.

Preserve build artifacts with matching source and configuration when they are
needed for field diagnosis or reproducible programming.

## Device Documentation

Use the exact device datasheet, silicon errata, instruction-set documentation,
pack release notes, and programmer documentation. Verify memory maps, vector
tables, fuse polarity and defaults, clock startup, programming voltage,
interface pin use, and signature bytes from those sources rather than from a
nearby family member.
