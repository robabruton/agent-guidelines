# ESP-IDF Project Layout

Use the repository as the source of truth. ESP-IDF permits several layouts,
and a project does not need every conventional directory.

## Project Files

- Top-level `CMakeLists.txt`: normally sets the minimum CMake version, includes
  ESP-IDF's `project.cmake`, and declares the project. Inspect it to confirm the
  project root and any build-time policy.
- `main/`: the special application component. It usually has its own
  `CMakeLists.txt` and application entry point.
- `components/`: optional local components discovered by the build system.
  Create it only when the project has a component to place there.
- Additional component directories: projects can register component roots
  outside `components/`. Read the top-level build configuration before moving
  or creating components.
- `managed_components/`: dependency-manager output. Regenerate it through the
  component manager; do not edit vendored contents in place.
- `build/`: generated CMake, Ninja, binary, ELF, map, and flashing output.
  Treat it as disposable only after verifying that the path contains no user
  data or unpreserved diagnostics.

## Component Files

- `CMakeLists.txt`: registers sources, include paths, embedded data, and public
  or private component dependencies with `idf_component_register`.
- `idf_component.yml`: declares managed dependencies and component metadata.
- `Kconfig` or `Kconfig.projbuild`: defines configuration options and their
  visibility. Trace defaults and dependencies before changing an option.
- Public headers: normally live under the component's declared include path.
- Private headers and sources: keep implementation details outside public
  include paths unless consumers require them.

Do not move code out of `main` solely to create structure. Extract a component
when it has a coherent responsibility, dependency boundary, reuse case, or
independent test surface.

## Configuration and Dependency State

- `sdkconfig.defaults` and target-specific default files: maintained inputs for
  reproducible configuration. Follow the repository's established naming and
  layering.
- `sdkconfig`: configured project state generated or updated by ESP-IDF tools.
  Repositories differ on whether they track it; inspect local policy rather
  than imposing one.
- `dependencies.lock`: resolved managed-component dependency state. Determine
  whether the repository treats it as a reproducibility input before changing
  or removing it.
- `idf_component.yml`: maintained dependency constraints; use the component
  manager to update resolution rather than editing resolved component sources.
- Partition CSV: maintained layout input when the built-in tables are not used.
  Confirm offsets, sizes, flags, OTA layout, and application fit.

Configuration and lock files can change when the framework, target, defaults,
or managed dependencies change. Review those diffs for intentional effects.

## Common Generated Artifacts

Locate artifacts from the active build rather than assuming fixed filenames:

- Application ELF and binary
- Linker map
- Bootloader binary
- Partition-table binary
- Flash argument files and project description metadata
- Size reports and test output

Keep the ELF, map, configuration, partition table, and serial log together when
preserving evidence for a crash or field failure.
