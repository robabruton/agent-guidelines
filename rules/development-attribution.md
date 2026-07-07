---
when: always
load: always
summary: >-
  Excludes AI-tool authorship from the project record. No trailer
  lines naming AI tools or code assistants, no references to AI tools
  as authors of committed work, no naming of agent tooling in ignore
  files or build configs, and no hardcoded model or vendor names in
  source. Functional references to AI as a user-facing feature are
  allowed; references to AI as a developer or contributor are not.
---
# Development Attribution Rules

## Hard Constraints

- Never add authorship trailers (`Co-Authored-By`, `Generated-by`, or
  similar) to commit messages or committed content.
- Never present AI tools, LLMs, code assistants, or automation tools
  as having developed, written, generated, reviewed, or planned any
  part of the project.
- Never name agent or assistant tooling in any tracked file — ignore
  files, build configs, and paths included, not just prose.
- Never hardcode model or vendor names in source code, comments,
  docstrings, or committed documentation.
- References to AI as user-facing project functionality are allowed;
  references to AI as a development author or contributor are not.
- When in doubt, ask.

## Details and Rationale

- These bans cover all tracked content: code comments, documentation,
  README content, changelog entries, and every other committed file.
- The hooks installed by `project-setup.sh` reject authorship trailers
  in commit messages and staged content regardless of who is named,
  since a pattern cannot tell tool names from human names. Credit
  human collaborators in commit body prose rather than trailers.
- Functional references describe project functionality, integrations,
  APIs, or user-facing behavior — they must not imply a tool was a
  development contributor.
- If a build or packaging step would otherwise sweep in local tooling
  files, exclude them with an allowlist of the project's own files
  rather than by naming the tooling.
- Model names change, tie the code to one vendor, and go stale; keep
  model selection in configuration and use generic language ("the
  configured model", "the provider/model identifier") in code and docs.
