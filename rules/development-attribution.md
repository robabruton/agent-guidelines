---
when: always
load: always
summary: >-
  Excludes development-tool authorship from the project record while
  allowing factual product integrations, APIs, configuration, paths,
  compatibility notes, and user-facing behavior.
---
# Development Attribution Rules

## Hard Constraints

- Never add authorship trailers (`Co-Authored-By`, `Generated-by`, or
  similar) to commit messages or committed content.
- Never present AI tools, LLMs, code assistants, or automation tools
  as having developed, written, generated, reviewed, or planned any
  part of the project.
- Keep model selection configurable rather than hardcoding a provider
  or model identifier into source behavior.
- Name tools, vendors, models, paths, and configuration keys when they
  are factual parts of functionality, compatibility, or usage.
- When in doubt, ask.

## Details and Rationale

- The authorship ban covers commit messages and all tracked content.
- Hooks installed by `project-setup.sh` reject high-confidence
  development provenance in commit messages and added staged lines.
  Contextual or ambiguous wording still requires manual review.
- Functional references describe project functionality, integrations,
  APIs, generated product output, provider-specific configuration,
  compatibility, or user-facing behavior. They must not imply a tool
  was a development contributor.
- Prefer generic source interfaces such as "the configured model";
  documentation and configuration may name supported providers and
  models when users need those names to operate the product.
