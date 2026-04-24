# Backward Compatibility Rules

Preserve existing behavior unless the branch explicitly replaces it.
Breaking changes should be intentional, documented, and easy to identify.

## Compatibility Check

- Identify whether a change affects public APIs, command-line flags,
  configuration, file formats, data formats, install behavior,
  documented workflows, or user-facing output
- Preserve existing behavior when practical, even while adding new behavior
- Do not remove or rename behavior that users may rely on without documenting the impact
- If compatibility cannot be preserved, explain what breaks and why

## Replacements, Removals, and Migrations

- A branch that replaces existing behavior must include the replacement
  before it is merged
- A branch that removes existing behavior must make the removal
  intentional and documented before it is merged
- Explain why a feature, command, config, API, file format, or workflow
  is being removed
- Provide migration notes when users need to change commands, config,
  data, paths, or workflows
- Prefer deprecation warnings or transition periods when the project has
  users who may depend on the old behavior
- Remove or update related documentation, examples, tests,
  configuration, and changelog entries in the same branch

## Release Impact

- For versioned projects, breaking changes require a `MAJOR` version
  recommendation
- Backwards-compatible feature additions generally warrant a `MINOR`
  version recommendation
- Backwards-compatible fixes generally warrant a `PATCH` version recommendation
- User-facing removals are breaking changes unless the removed behavior
  was explicitly private, experimental, or already deprecated
- If a change is intentionally not considered breaking, explain the
  compatibility reasoning during final review
