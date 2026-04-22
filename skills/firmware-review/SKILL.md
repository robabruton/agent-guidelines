---
name: firmware-review
description: Review embedded firmware, drivers, RTOS code, ISRs, hardware-facing C/C++, and protocol code for correctness, timing, concurrency, and hardware-integration issues.
when_to_use: Use when reviewing embedded C/C++, drivers, board support packages, RTOS tasks, ISRs, register access, DMA flows, startup/linker code, bootloaders, or device protocols.
argument-hint: "[file|directory|component|branch|changes]"
allowed-tools: Read Grep Glob
---

Review firmware and hardware-facing code for defects that ordinary code
review can miss. Use this skill when asked to review embedded C/C++,
drivers, board support packages, RTOS code, interrupt handlers, startup
code, linker assumptions, register access, DMA flows, bootloaders, or
device protocols.

## Target Selection

Determine the review target from the user request:

- No target: review changed firmware source, headers, linker files, and
  build configuration.
- File path: review that source, header, linker script, or configuration
  file.
- Directory path: review firmware code under that directory.
- Component name: locate and review the relevant driver, peripheral,
  board, RTOS, boot, or protocol code.

For changed-code reviews, inspect both staged and unstaged changes. Use
`git diff --name-only`, `git diff --cached --name-only`, and
`git status --short` when available.

Prefer `rg --files` to find likely targets. Include `.c`, `.h`, `.cpp`,
`.hpp`, `.S`, `.s`, `.ld`, `.lds`, linker fragments, startup files,
board files, HAL/LL drivers, RTOS tasks, interrupt vector tables,
protocol parsers, bootloader code, hardware configuration files, device
trees, Kconfig files, CMake or Make build files, board metadata, pin
configuration files, clock configuration files, and vendor tool
configuration such as `.ioc` files.

If the target is not firmware, embedded, hardware-facing, or
resource-constrained code, say that this skill is not the right review
lens and switch to a more appropriate review.

## Review Areas

Focus on issues that can cause target-only failures, race conditions,
missed interrupts, corrupted data, timing faults, unsafe hardware state,
or field recovery problems.

### Interrupts and Callbacks

- Blocking work, heap allocation, logging, sleeps, or long loops inside
  interrupt context.
- Shared state accessed from both ISR and task/thread context without
  the required `volatile` visibility, atomicity, barriers, locks, or
  critical sections.
- Interrupt flags cleared in the wrong order.
- Missed reentrancy or nested-interrupt assumptions.
- Callback lifetime or ownership assumptions that can outlive buffers,
  handles, or peripheral state.
- Priority, preemption, and interrupt-mask assumptions that can break
  latency or shared-state protection.

### Registers and Peripherals

- Wrong masks, shifts, reset values, or register widths.
- Read-modify-write hazards on registers with write-one-to-clear,
  write-only, read-clear, reserved, or concurrently updated bits.
- Missing peripheral clock, reset, pin mux, alternate-function, or power
  sequencing setup.
- Reserved bits written without preserving documented values.
- Status polling that fails to clear, acknowledge, or sequence hardware
  events correctly.
- Peripheral ownership changes that do not quiesce hardware, drain FIFOs,
  disable interrupts, or wait for in-flight transfers.

### Timing and Clocks

- Busy waits without timeout or recovery.
- Timeout math that fails across counter wraparound.
- Clock, tick, prescaler, baud, sample-rate, or timer assumptions that do
  not match configuration.
- Delay loops that depend on optimization level, CPU frequency, cache, or
  wait states.
- Race windows around enable, disable, reset, sleep, wake, or low-power
  transitions.
- Time comparisons written as absolute greater-than checks instead of
  wrap-safe elapsed-time checks.

### DMA, Cache, and Buffers

- DMA buffers with incorrect alignment, lifetime, region, or ownership.
- Missing cache clean, invalidate, or memory barriers on cached systems.
- CPU and DMA writing the same buffer without a clear handoff.
- Stack buffers passed to asynchronous DMA or peripheral operations.
- Ring buffer, descriptor, or queue wraparound errors.
- Partial transfer and error-completion paths that leave stale data.
- Missing `const`, `static`, section placement, or non-cacheable memory
  attributes required by the target.

### RTOS and Concurrency

- Mutexes, semaphores, queues, notifications, or critical sections used
  from the wrong context.
- Priority inversion, deadlock, missed wakeup, or unbounded blocking.
- Shared hardware accessed from multiple tasks without serialization.
- Task stack size, lifetime, or startup-order assumptions.
- ISR-to-task signaling that can drop events or overflow queues.
- Memory-order assumptions across cores, DMA, interrupts, or RTOS
  primitives.

### Memory and Undefined Behavior

- Buffer bounds, integer overflow, sign conversion, alignment, and
  strict-aliasing issues.
- Use of uninitialized memory, stale pointers, or invalidated handles.
- Stack pressure from large locals, recursion, or deep call chains.
- `volatile` used as a substitute for atomicity when it is insufficient.
- Undefined behavior that may only appear under optimization or LTO.
- Lifetime assumptions around memory-mapped registers, packed structs,
  unaligned accesses, and strict volatile access requirements.
- Missing `const`, `static`, or ownership boundaries that allow accidental
  mutation of hardware configuration or shared buffers.

### Startup, Linker, and Build Configuration

- Linker script regions that do not match the target memory map.
- Sections, vector tables, boot metadata, or retained memory placed in
  the wrong region.
- Weak symbols, startup hooks, or initialization order relied on
  implicitly.
- Feature flags, board variants, or conditional compilation that create
  untested hardware combinations.
- C/C++ runtime initialization assumptions in early boot code.
- Startup code that enables interrupts, clocks, caches, FPU, MPU, or MMU
  in an unsafe order.
- Build flags that change ABI, floating-point mode, structure packing,
  optimization, assertions, logging, or fault behavior.

### Protocols and External Inputs

- Framing, length, checksum, CRC, endian, alignment, or version parsing
  mistakes.
- Malformed packet handling that can desynchronize state.
- Trusting peripheral, bus, radio, host, or bootloader inputs.
- State machines with missing transitions, impossible recovery, or
  inconsistent timeout behavior.
- Replay, downgrade, or rollback concerns when firmware update or boot
  flows are involved.
- Backpressure, flow-control, retransmission, and buffer exhaustion paths
  that can drop or corrupt data.

### Faults and Recovery

- Watchdog servicing that hides deadlocks or long fault paths.
- Fault handlers that lose diagnostic state or return unsafely.
- Peripheral error paths that do not reset hardware or drain stale state.
- Brownout, reset, low-power, and hot-plug assumptions.
- Degraded mode, retry, and fail-safe behavior that is missing or
  unclear.
- Persistent state, calibration, counters, logs, or flash writes that can
  corrupt data during reset or power loss.

### Safety and Diagnostics

- Assertions, panic paths, and fault handlers that are disabled or unsafe
  in production builds.
- Diagnostics that are too late, too verbose, or unavailable after a
  fault.
- Safety-critical outputs that do not move to a known safe state on
  error, reset, or watchdog recovery.
- Calibration, limits, and sensor plausibility checks that fail open.

## Review Process

1. Identify the target MCU, SoC, board, RTOS, peripheral, and toolchain
   assumptions when the code reveals them.
2. Read the relevant files before forming findings.
3. Trace hardware ownership, interrupt/task interactions, buffer
   lifetimes, register sequencing, and error paths.
4. For diffs, inspect surrounding initialization, teardown, ISR,
   callback, and error-handling context instead of reviewing only changed
   lines.
5. Compare code against nearby driver patterns and documented local
   conventions.
6. Use datasheets, reference manuals, errata, or RTOS documentation when
   they are available in the repository or supplied by the user.
7. Use static analysis, compiler diagnostics, map files, or host-side
   tests when they are available and relevant, but confirm each finding
   against the firmware behavior.
8. Report only issues that could affect correctness, timing, safety,
   recoverability, or target behavior.

Do not spend findings on style, naming, formatting, or generic C/C++
preferences unless they create a concrete firmware failure mode.

Do not turn this into a broad security audit. Report security concerns
only when they affect firmware update, boot, external input handling,
hardware exposure, debug access, or device safety in the reviewed code.

Do not assume hardware facts that are not in the code or provided
documentation. Label such items as assumptions to verify.

Do not recommend fixes that ignore target constraints such as interrupt
latency, memory footprint, stack limits, code size, power budget,
determinism, certification requirements, or available hardware features.

Do not run flashing, erase, debug-probe, hardware reset, serial console,
or target-interacting commands unless the user explicitly asks for that
execution. Prefer static review, host-side tests, compile checks, and
repository-provided simulation or unit tests.

## Finding Standard

Each finding must include:

- The condition that triggers the issue.
- The realistic target consequence.
- The specific code path, register sequence, buffer, ISR, task, or state
  transition involved.
- A concrete fix, mitigation, or hardware verification step.

Suppress a concern when it is only theoretical, contradicts surrounding
guards, depends on undocumented hardware behavior, or is a style
preference without a firmware failure mode. If a concern depends on an
MCU, board, toolchain, RTOS, or peripheral detail that was not verified,
label it as an assumption to check.

For generated code, vendor HAL code, or board configuration emitted by a
tool, distinguish between defects in generated output and defects in
user-owned configuration. Prefer fixing the source configuration when the
generated file is not meant to be edited directly.

## Output Format

Lead with findings grouped by severity:

```text
Critical
- path:line - Issue. Suggested fix or verification.

High
- path:line - Issue. Suggested fix or verification.

Medium
- path:line - Issue. Suggested fix or verification.

Low
- path:line - Issue. Suggested fix or verification.
```

Use these severities:

- **Critical:** Likely unsafe hardware state, memory corruption, bricking,
  unrecoverable boot failure, or field data loss.
- **High:** Realistic interrupt loss, race, DMA/cache corruption,
  protocol desynchronization, watchdog masking, or hardware missequence.
- **Medium:** Timing, portability, configuration, recovery, or edge-case
  issue likely to affect some targets or operating modes.
- **Low:** Minor robustness, diagnostics, or maintainability issue with a
  plausible firmware impact.

After findings, include:

- A short summary of the firmware surfaces reviewed.
- Hardware, RTOS, toolchain, and documentation assumptions.
- Tests, builds, static checks, or simulations run, if any.
- Residual target-only risk that could not be verified without hardware.

If no issues are found, say that clearly and still state what was
reviewed, what assumptions remain, and what was not target-tested.
