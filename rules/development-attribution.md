---
when: always
load: always
---
# Development Attribution Rules

- Do not include `Co-Authored-By` lines referencing AI tools, code
  assistants, or automation tools in commit messages
- Do not reference AI tools, LLMs, code assistants, or automation tools
  as having developed, written, generated, reviewed, or planned any part
  of the project
- This applies to code comments, documentation, commit messages, README
  content, changelog entries, and all other committed files
- References to AI or automation are allowed when they describe project
  functionality, integrations, APIs, or user-facing behavior
- Functional references must not imply that a tool was used as a
  development author or contributor
- Do not name agent or assistant tooling in tracked files at all — this
  includes ignore files, build configs, and paths, not just prose. If a
  build or packaging step would otherwise sweep in local tooling files,
  exclude them with an allowlist of the project's own files rather than by
  naming the tooling
- Do not hardcode specific model or vendor names — product names, model
  identifiers, or versioned model strings — in source code, comments,
  docstrings, or committed documentation. Model names change, tie the code
  to one vendor, and go stale; keep model selection in configuration and
  use generic language ("the configured model", "the provider/model
  identifier") in code and docs
- When in doubt, ask
