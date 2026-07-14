# ESP-IDF Research

Resolve questions against the exact ESP-IDF release or commit, chip target,
project configuration, toolchain, and connected hardware. Do not combine APIs,
flags, Kconfig symbols, examples, or device behavior from different releases
or chip families without identifying the difference.

## Source Order

Use this order unless the question requires a narrower primary source:

1. Repository instructions, component manifests, CMake files, Kconfig files,
   `sdkconfig` inputs, partition tables, build output, and matching artifacts.
2. Live version, environment, help, verbose, diagnostic, and read-only commands
   from the active `idf.py`, compiler, CMake, Ninja, esptool, OpenOCD, GDB, or
   other utility.
3. Headers, source, Kconfig definitions, CMake modules, examples, tests, and
   documentation in the active ESP-IDF installation and its installed tools.
4. The exact chip's datasheet, technical reference manual, errata, hardware
   design guidance, and programming or security documentation.
5. Version-matched primary online ESP-IDF documentation, release notes, API
   references, component registry records, and upstream tool documentation.
6. Secondary sources only to form hypotheses that can be checked against the
   project, installed implementation, hardware documentation, or another
   primary source.

Prefer the installed framework for implementation truth and the matching
published documentation for explanation. Record when they disagree. Never
present documentation for the latest release as proof of behavior in an older
or development checkout.

## Live Help and Diagnostics

Start by identifying the selected installation and target. Use read-only
commands such as `idf.py --version`, `idf.py --help`, command-specific help,
compiler `--version`, and the relevant tool's native help before relying on a
remembered flag. Check whether the active version exposes a diagnostic command
before invoking it.

For a failure, preserve the complete command, output, environment selection,
target, configuration, and matching build artifacts. Search the exact primary
error text without discarding the surrounding diagnostics. Increase verbosity
only through a flag or environment setting supported by the active version.
Do not use cleanup, reconfiguration, dependency updates, erase, flash, reset,
or probe access merely to obtain more information.

## API and Component Questions

Start from the header in the active installation, then trace its implementation,
Kconfig guards, component registration, public and private dependencies,
initialization order, callbacks, task or ISR context, ownership, lifetime, and
error-return contract. Inspect examples from the same release, but verify their
target and configuration assumptions before adapting them.

For managed components, identify the resolved component version and manifest
rather than assuming the registry's current release. For renamed, deprecated,
or removed APIs, use the selected ESP-IDF release notes and migration guidance
that span the project's actual version boundary.

## Chip and Protocol Questions

Separate framework behavior from chip behavior. Reconcile driver source and
Kconfig with the exact chip's peripheral capabilities, register definitions,
clocking, DMA restrictions, memory regions, radio coexistence constraints,
electrical limits, and errata. Treat wireless binary libraries and other
prebuilt components as versioned framework inputs; do not infer unavailable
implementation details. Use their documented interfaces, configuration,
release notes, and observed diagnostics.

## Online Research

When current status, release support, compatibility, security guidance, or
documentation links matter, browse primary sources and cite the pages that
support the answer. State whether a conclusion comes directly from a source,
the installed implementation, a hardware observation, or an inference. If an
answer cannot be matched to the project's version and target, report that
limit instead of generalizing.
