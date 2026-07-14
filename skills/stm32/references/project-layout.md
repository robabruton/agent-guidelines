# STM32 Project Layout

STM32 projects can be generated, IDE-owned, or hand-maintained. Determine file
ownership from repository policy and generator configuration before editing.

## CubeMX and CubeIDE Projects

Inspect:

- `.ioc` device, pin, clock, peripheral, middleware, and project settings.
- CubeMX and MCU firmware package versions.
- STM32CubeIDE `.project`, `.cproject`, and `.settings/` metadata when present.
- Generated `Core/Inc`, `Core/Src`, startup assembly, system file, linker
  scripts, drivers, middleware, and build configuration.
- Generator settings for copied versus referenced libraries and preserved user
  sections.

Do not assume every file containing generated markers is safe to replace. Back
up the complete project, regenerate through the project's established tool
version, and review the entire diff. Code outside preserved regions can be
overwritten; code inside them can still become semantically incompatible with
new initialization.

## CMake, Make, and Other IDEs

Inspect the maintained source lists, preprocessor definitions, include paths,
CPU/FPU/float-ABI flags, startup object, linker script, CMSIS and HAL/LL paths,
libraries, post-build conversion, programmer, and debug configuration. Keep
compile, link, debugger, and programmer target selection consistent.

Do not replace a repository's build system merely to match a preferred STM32
tool. Preserve reproducible command-line entry points when the project has
them.

## Firmware Package Layers

Classify:

- CMSIS core and device headers, startup, and system files.
- STM32 HAL and LL drivers.
- Board support packages and external-component drivers.
- Middleware and RTOS sources.
- Application-owned source and configuration.

Treat HAL as the normal application driver layer. LL may coexist per peripheral
when selected in CubeMX or maintained explicitly by the project. Trace HAL and
LL initialization, interrupt, DMA, clock, and ownership interactions before
mixing them; do not bypass HAL state behind an active HAL handle accidentally.

Record the STM32Cube MCU package and component versions. Do not combine files
from different package releases without an explicit compatibility change.

## Memory and Boot Inputs

Inspect:

- Linker scripts and memory regions.
- Vector-table location and relocation.
- Bootloader and application origins.
- Single-bank, dual-bank, external-memory, and multicore layouts.
- Stack, heap, no-init, retained, DMA, cache-sensitive, and special sections.
- Option bytes or boot configuration on which the layout depends.

Verify these against the exact MCU reference material and board memory, not a
nearby device in the same family.

## Generated Artifacts

Common outputs include ELF, BIN, Intel HEX, map, listing, disassembly,
programming files, and IDE build directories. Locate them through actual build
metadata. Preserve the ELF, map, linker script, configuration, and binaries
together for crash diagnosis or reproducible programming.
