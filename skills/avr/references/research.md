# AVR Research

Resolve questions against the exact device and the tools that build and program
the project. Similar AVR families can differ in register layout, fuse encoding,
memory access, interrupt vectors, and programming behavior.

## Evidence Order

Use sources in this order:

1. Repository instructions, build files, compiler commands, linker inputs,
   programmer commands, and known-good project behavior.
2. Live `--version`, `--help`, verbose, device-list, and dry-run or no-write
   output from the exact compiler, Binutils, build tool, and programmer.
3. Installed AVR headers, device specifications, startup objects, linker data,
   AVR-LibC headers/source/manual, and programmer configuration.
4. Exact-device datasheet, silicon errata, programming specification, and
   official board or probe documentation.
5. Version-matched primary documentation and release notes for AVR GCC,
   AVR-LibC, Binutils, avrdude, or the selected programming/debug tool.
6. Official or upstream examples matching the device family and tool version.
7. Secondary discussions only to discover hypotheses, never as the sole basis
   for register, fuse, timing, or destructive-operation advice.

When current behavior, versions, support, or syntax may have changed, browse
primary vendor or upstream sources and cite the pages used. Do not quote or
copy advice for a nearby device without checking the exact-device documents.

## Library and API Questions

Start from the header included by the build and trace macros, inline functions,
conditional compilation, device guards, implementation source, and linker
requirements. Confirm that online documentation matches the installed
AVR-LibC or library version. Compile a minimal isolated example when semantics
remain uncertain and no hardware operation is required.

## Register, Fuse, and Timing Questions

Use the exact datasheet revision and errata. Trace register reset values,
reserved bits, write-one-to-clear behavior, synchronization, clock domain,
interrupt flags, fuse polarity, and programming-interface consequences.
Recalculate timing from the project's physical clock and fuse configuration;
do not trust an example's `F_CPU`.

## Tool Diagnostics

Capture the complete command, version, first actionable error, surrounding
warnings, search paths, device selection, and programmer output. Consult live
help before web results. Re-run with the tool's documented verbose or no-write
mode when safe, then look up the exact diagnostic in version-matched primary
documentation or upstream issue history.

## Examples and Conclusions

Treat examples as evidence of an API pattern, not as device configuration to
copy. Verify device, clock, pins, programmer, memory map, tool version, and
errata before adapting one. Separate facts supported by sources from inferences
and state what remains unverified on hardware.
