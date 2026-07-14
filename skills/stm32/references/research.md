# STM32 Research

Resolve questions against the exact MCU, board, Cube package, generated
configuration, and tools used by the project. STM32 series and even parts in
one series can differ in registers, memory, errata, boot behavior, and security
features.

## Evidence Order

Use sources in this order:

1. Repository instructions, `.ioc`, generated configuration, build commands,
   linker and startup inputs, programmer/debugger configuration, and known-good
   project behavior.
2. Live version, help, verbose, device-list, and read-only output from the exact
   compiler, Cube tools, programmer, OpenOCD, and debugger.
3. Installed STM32Cube package headers, HAL/LL source, CMSIS device files,
   middleware source, package documentation, release notes, and matching
   examples.
4. Exact-device datasheet, reference manual, programming manual, silicon
   errata, application notes, and board/probe documentation.
5. Version-matched primary online documentation for CubeMX, CubeIDE or CubeCLT,
   CubeProgrammer, HAL/LL, CMSIS, OpenOCD, or the selected tool.
6. Official examples matching the MCU family, peripheral, package version, and
   board assumptions.
7. Secondary discussions only to discover hypotheses, never as the sole basis
   for register, clock, option-byte, memory, or security advice.

Browse primary vendor or upstream sources when versions, support, syntax, or
behavior may have changed, and cite the pages used. Do not apply guidance for a
nearby part until its registers, memory map, errata, and package implementation
are verified against the exact target.

## HAL and LL API Questions

Start from the header and source in the project's installed Cube package. For
HAL, trace handle state, initialization and MSP hooks, weak callbacks,
interrupt/DMA entry points, locking, timeouts, and conditional modules. For LL,
trace the exact register operations, required clocks, ordering, flags, and
interaction with any HAL-owned peripheral state.

Confirm that online API documentation matches the package version. Use a
matching official example to understand sequencing, then adapt it to the
project's clock, pins, DMA, interrupt priorities, cache, RTOS, and board.

## Register, Clock, and Memory Questions

Use the exact reference manual revision and errata. Trace reset values,
reserved bits, write-one-to-clear behavior, synchronization, clock domains,
bus limits, voltage scaling, flash latency, cache, DMA visibility, and memory
attributes. Reconcile Cube-generated settings with runtime code and physical
board clocks.

## Tool Diagnostics

Capture the complete command, tool and package versions, first actionable
error, surrounding warnings, target/probe identity, generated paths, linker
script, and protection state. Consult live help and installed documentation
before web results. Re-run with documented verbose or read-only diagnostics
when safe, then search exact diagnostics in version-matched primary docs or
upstream issue history.

## Examples and Conclusions

Treat examples as evidence of sequencing and API contracts, not as pin, clock,
memory, or security configuration to copy. Separate sourced facts from
inferences and state which behavior remains unverified on the target hardware.
