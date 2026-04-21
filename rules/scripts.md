# Script Rules

Scripts should be predictable, readable, and safe to run more than once.
Prefer clear behavior over clever shortcuts.

## Safety

- Use strict error handling appropriate for the scripting language
- For non-trivial Bash scripts, use `set -euo pipefail`
- Quote or escape values that may contain paths, whitespace, shell metacharacters, or user-provided input
- Validate required commands, files, directories, and inputs before making changes
- Avoid destructive commands such as `rm -rf` unless the behavior is explicit, narrowly scoped, and documented
- Prefer moving conflicting files to a backup location over deleting them

## User Interface

- Provide help output for scripts intended to be run directly
- Support a dry-run or preview mode for non-interactive scripts that create, modify, move, or remove files when planned changes can be predicted reliably
- For interactive or long-running scripts where dry-run is not practical, preview destructive or high-impact actions before performing them
- Print what the script is doing using clear action labels
- Use color and symbols only when they improve scanning and do not hide important details
- Keep output grouped by the type of work being performed, followed by a concise summary
- Keep verbose or debug output behind an explicit flag or mode

## Idempotency

- Scripts should be safe to run repeatedly
- Detect already-correct state and skip it without treating it as an error
- Do not create duplicate files, duplicate config blocks, or repeated backup copies for already-managed state
- Distinguish between managed files, foreign files, regular files, directories, and missing paths before changing anything

## Errors and Cleanup

- Fail clearly on unknown flags, invalid arguments, and invalid flag combinations
- Use nonzero exit codes for failures and zero for success or intentional no-op results
- Check required external commands or runtime dependencies before starting work
- Use temporary files safely and clean them up when the script exits
- Prefer writing important file changes to a temporary file and moving it into place
- For long-running scripts, consider how interruption leaves partially completed work

## Portability

- Use language-specific features only when the script declares or documents the required runtime
- Prefer portable commands and document platform assumptions when they matter
- Do not rely on user- or machine-specific absolute paths
- Prefer project-root-relative paths or documented environment variables
