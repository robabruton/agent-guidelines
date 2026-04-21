# Documentation Rules

Documentation must describe the project as it actually works. Do not
document planned behavior as if it already exists.

## Accuracy

- Update documentation when user-facing behavior, setup, configuration, commands, or workflows change
- Major features should include documentation in the same branch, or the final branch review should explicitly ask whether documentation should be added
- Keep README instructions aligned with the current repository contents
- Describe limitations, prerequisites, and assumptions when they affect usage
- Remove stale instructions instead of leaving contradictory guidance in place
- If documentation is intentionally deferred, say why and identify what still needs to be documented

## Examples

- Examples should be runnable or clearly marked as illustrative
- Commands should use realistic paths, flags, and filenames
- Do not include placeholder URLs, package names, or commands in final documentation unless the placeholder is intentional and explained
- Keep examples small enough to verify during review

## Scope

- Prefer documenting behavior where the project already keeps related documentation
- Documentation may live in `docs/`, the root `README.md`, package or module READMEs, comments, or another project-appropriate location
- Do not duplicate long explanations across files unless each copy serves a different audience
- When documentation changes without behavior changes, keep the commit scoped as documentation only
