# ESP-IDF Operations

Verify every command against the active ESP-IDF installation. The commands
below identify common operations; supported flags and target names vary by
release and project.

## Inspect and Activate

- Read repository instructions and environment wrappers first.
- Use `idf.py --version` to identify the active framework.
- Inspect `IDF_PATH`, `IDF_TOOLS_PATH`, and the Python and compiler paths.
- Use `idf.py --help` and command-specific help for live syntax.
- Check project configuration and build metadata for the selected target.

Do not install, update, activate a different version, or rewrite persistent
shell configuration unless the user requests that scope.

## Create and Configure

- Use the active version's project-creation command for a minimal project.
- Use the active version's component-creation command when a local component is
  actually needed, then inspect the generated registration before extending it.
- Use `idf.py set-target <target>` only after confirming the board and backing
  up configuration state that the operation can replace.
- Use `idf.py menuconfig` for interactive configuration when available.
- Use the supported defaults/export workflow to place shared defaults in
  maintained configuration inputs.
- Use `idf.py reconfigure` after build inputs change when an ordinary build
  does not perform the needed regeneration.

Review configuration diffs after target, framework, or Kconfig changes.

## Components and Dependencies

- Register sources, include paths, and dependencies in the component's
  `CMakeLists.txt`.
- Declare managed dependencies in `idf_component.yml` or through the active
  version's component-manager command.
- Re-resolve dependencies through ESP-IDF tooling and inspect manifest, lock,
  and generated-component changes together.
- Never patch `managed_components/` as the authoritative fix. Change the local
  component, constraint, override, or upstream dependency that owns the code.

## Build, Size, and Test

- `idf.py build`: configure as needed and build the project.
- `idf.py app`, `bootloader`, or `partition-table`: build a narrower artifact
  when supported and sufficient.
- `idf.py size` and related size commands: inspect image and memory use.
- Repository test commands: prefer the documented host, component, integration,
  or hardware test entry point over inventing a parallel workflow.

Inspect the full output and verify generated artifacts. Confirm that application
images fit the selected partition table and that size changes are expected.

Use cleanup only for evidence that stale generated state is causal:

- Narrow clean operations affect selected build outputs.
- `idf.py fullclean` removes generated build state. Inspect the resolved build
  directory, preserve diagnostics or foreign contents, and verify any required
  backup before running it.

## Flash and Monitor

Only access a board when the user requests target operations.

- Discover candidate serial ports or debug probes without mutating them.
- Require an explicit port or an unambiguous mapping to the identified board.
- Confirm target, flash settings, and partition layout before writing.
- `idf.py -p <port> flash`: build as needed and write the configured images.
- `idf.py -p <port> monitor`: open the serial monitor.
- `idf.py -p <port> flash monitor`: flash and then observe boot when both
  operations are requested.
- Record the documented monitor exit sequence for the active version; commonly
  it is `Ctrl+]`.

Do not treat opening a port, resetting a board, or reading a chip identifier as
permission to erase or flash it. Confirm destructive or irreversible operations
at their actual scope.

## Debug Probes and Device State

OpenOCD, GDB, JTAG reset, flash erase, eFuse changes, secure-boot provisioning,
and flash-encryption transitions can stop running firmware or permanently alter
the device. Identify the probe and board, inspect current state, preserve data
when applicable, and obtain the required authorization before acting.

## Verification Matrix

Report each layer separately:

- Configure: build system generated successfully for the intended target.
- Build: expected artifacts exist and size/partition checks pass.
- Flash: the tool reports that the intended images were written to the intended
  device.
- Boot: serial or debugger evidence shows the new image started.
- Behavior: the requested firmware behavior was actually exercised.

Do not collapse these into a single claim of success.
