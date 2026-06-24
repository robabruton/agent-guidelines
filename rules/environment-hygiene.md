---
when: installing dependencies, moving or regenerating envs, or working across target platforms
load: recall
---
# Environment Hygiene Rules

Lessons about the development environment itself — where dependencies
live, how tools resolve, and why committed files must run somewhere other
than the machine that wrote them. These prevent a class of "works on my
machine" failures that are slow to diagnose.

## Never Install Dependencies Above the Project

Do not install packages into a location that places a dependency
directory at or above the user's home directory, or any ancestor of the
project.

- Many package managers resolve by walking up parent directories. A
  package found in an ancestor is treated as already satisfied, so the
  local install is skipped — and code then loads a different copy than
  intended. The classic symptom is a duplicate-instance error (two copies
  of a framework loaded at once) that is hard to trace.
- Always run install commands from inside the project (or the specific
  sub-project) that should own the dependencies. Verify the dependency
  landed in the project's own dependency directory and that no stray
  one exists in a parent.

## Regenerate Environments After Moving or Renaming Package Directories

When a package directory is moved or renamed, virtual-environment
entry-point scripts can keep absolute paths that point at the old
location.

- The failure is sneaky: a runner may silently fall back to a tool found
  on the system path, running under the wrong interpreter, so imports of
  the project fail while the build looks healthy.
- After moving or renaming a package, recreate its environment from
  scratch (delete and re-sync) so entry-point scripts get correct paths.
- Diagnostic: if a project's own module fails to import under the task
  runner but imports fine under a direct interpreter invocation, suspect a
  stale entry-point path first and check where the tool actually resolves.

## Committed Files Must Work on Every Target Platform

The machine you develop on is not the only place the project runs.
Committed scripts, container files, CI configs, and docs must work on all
the platforms the project targets — not just the developer's OS.

- No machine-specific absolute paths, OS-specific volume labels/flags, or
  package-manager assumptions baked into committed files.
- Where a committed file genuinely needs a platform-specific value (a
  certificate bundle path, a package name), detect it or parameterize it,
  and document the assumption.
- Platform-specific shortcuts are fine in throwaway local commands you run
  by hand — just keep them out of anything committed.

## Prefer High-Level Platform CLIs Over Raw API Calls

For routine operations against a hosting platform (pull/merge requests,
pipeline status, releases), use the platform's high-level CLI subcommands
rather than raw API calls.

- High-level subcommands are purpose-built and avoid manual response
  parsing.
- Fall back to the raw API only for operations the CLI does not support.
