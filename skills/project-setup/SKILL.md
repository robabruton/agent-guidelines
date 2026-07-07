---
name: project-setup
description: Initialize or update a repository with project rules, git hooks, commit standards, and agent configuration
when_to_use: Use when setting up a new repository or refreshing an existing repository with shared rules, local git hooks, changelog behavior, and agent instruction files.
argument-hint: "[target-dir] [options]"
---

Set up a project repository with reusable development standards. This
skill is idempotent: it checks what already exists, adds missing setup,
and avoids overwriting user-managed files.

Use this skill for both new repositories and existing repositories that
need project rules, git configuration, local hooks, or agent instruction
files refreshed.

The repository command that implements this target-repository workflow
is `project-setup.sh`; when it is available, run it instead of
performing the steps manually, and treat it as the authoritative
definition of profiles, rule selection, and file handling. Keep it
distinct from `setup.sh`, which links this repository's rules and
skills into local tool configuration directories.

## Target Directory

- Use the directory specified by the user
- If no directory is specified, use the current working directory
- If the target directory does not exist, create it
- Resolve and print the absolute target path before making changes

## Preflight

- Verify `git` is available
- Verify `user.name` and `user.email` are configured by checking local,
  global, then system git config
- If either value is missing, stop and tell the user how to configure it:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

- Inspect existing project files before asking setup questions
- Select a project profile:
  - `minimal` for empty, docs-only, or lightweight repositories
  - `codebase` for normal software projects with source, scripts,
    tests, dependency manifests, or build tooling
  - `released` for projects with users, releases, packages, APIs,
    plugins, CLIs, deployable services, or compatibility promises
- Infer `released` when version metadata, version-like tags, package
  metadata, public API indicators, or an existing versioned changelog
  are present
- Infer `codebase` when source files, tests, scripts, dependency
  manifests, or package managers are present
- Infer `minimal` for empty repositories, docs-only repositories, or
  unclear repositories
- Ask only when the profile cannot be inferred confidently
- If `CHANGELOG.md` exists:
  - Treat changelog maintenance as enabled
  - Infer `version` changelog mode if it contains `## [Unreleased]` or
    version headings such as `## [1.2.3] - YYYY-MM-DD`
  - Infer `date` changelog mode if it contains date headings such as
    `## 2026-04-21` and no version headings
  - If the format is mixed or unclear, summarize what was found and ask
    the user which mode to use
- If `CHANGELOG.md` does not exist:
  - Default to `version` changelog mode for the `released` profile
  - Default to `none` changelog mode for `minimal` and `codebase`
    profiles unless the user selects a changelog
  - If changelog mode is `date` or `version`, create a base
    `CHANGELOG.md`
  - If changelog mode is `none`, omit changelog rules and do not create
    `CHANGELOG.md`
- Inspect version indicators such as `package.json`, `pyproject.toml`,
  `Cargo.toml`, `go.mod`, `VERSION`, and tags matching `vX.Y.Z`
- Use version files and version-like tags as evidence that the project
  may use semantic versioning
- Use `versioning mode: semver` when changelog mode is `version`
- Use `versioning mode: none` when changelog mode is `none` or `date`
- Existing changelog structure takes priority over versioning guesses
- Print a short summary of the selected options before continuing
- Use `date` and `version` as the canonical changelog mode names in
  output, config, and generated instructions
- Accept `dated` and `dates` as aliases for `date`
- Accept `versioned` and `versions` as aliases for `version`

## Repository Setup

- Check whether the target directory is already inside a git work tree
- If it is not a git repository, run:

```bash
git init --initial-branch=main
```

- If it is already a git repository, do not reinitialize it
- If the existing default branch is not `main`, note it but do not rename
  branches automatically
- Report whether the repository was created or already existed

## Local Git Excludes

- Add local-only agent and tool files to `.git/info/exclude`
- Create `.git/info/exclude` if it does not already exist
- Append only missing exclude patterns and preserve existing user entries
- Do not add these patterns to `.gitignore`, because these files are
  local agent configuration rather than project artifacts
- Always exclude:
  - `CLAUDE.md`
  - `CLAUDE.local.md`
  - `AGENTS.md`
  - `.claude/`
  - `.codex/`
  - `.agent-guidelines/config`
- Exclude `.agent-guidelines/rules` when it is a symlink to a local
  canonical rules directory
- Exclude `opencode.json` only when it is private local configuration,
  not when the project intentionally tracks it as a shared artifact
- Exclude `.mcp.json` only when it is private local configuration, not
  when the project intentionally tracks it as a shared artifact
- If `opencode.json` or `.mcp.json` already exists and is tracked by git,
  leave it tracked and report that it was skipped

## Project Rule Assembly

- Create or update both `CLAUDE.md` and `AGENTS.md`
- Treat these files as local agent instruction files unless the target
  repository already tracks them intentionally
- Preserve all user-managed content outside managed marker blocks
- Use this marker block for generated project rules:

```markdown
<!-- BEGIN agent-guidelines project rules -->
<!-- END agent-guidelines project rules -->
```

- If the marker block exists, replace only the content inside the block
- If the marker block does not exist, append it to the end of the file
  after one blank line
- If the file does not exist, create it with only the managed block
- The managed block has two forms, selected by `--context-rules`:
  - `full`: every selected rule body is inlined into the block
  - `trimmed`: the block carries a rule selection header, one line
    stating the profile, changelog, and versioning modes, and a router
    table mapping each selected rule's trigger to its
    `.agent-guidelines/rules/<rule>.md` path; rule bodies are read on
    demand from those paths, and the always-tier rule text comes from
    the global context file installed by `setup.sh`
  - `auto` (default): per file — `CLAUDE.md` is trimmed when the
    global `~/.claude/CLAUDE.md` carries the managed block marker,
    and `AGENTS.md` is trimmed when any global `AGENTS.md` installed
    by `setup.sh` does; otherwise the file gets the full form. This
    keeps rules from loading twice in harnesses that read both a
    global and a project context file, while machines without the
    global install still get self-contained project files
- Record the requested mode as `context_rules=` in
  `.agent-guidelines/config`
- Keep rule source files separate from generated agent instruction files
- Prefer a symlinked rule source so projects can refresh generated
  instructions from updated central rules
- Use `.agent-guidelines/rules` in the target repository as the preferred
  project-local rule source path
- If `.agent-guidelines/rules` does not exist and symlink mode is
  selected, create it as a symlink to the canonical `rules/` directory
- If symlink creation is unavailable or the user selects copy mode, copy
  rule files into `.agent-guidelines/rules` as a snapshot
- Treat `.agent-guidelines/config` as local setup state that records the
  selected profile, changelog mode, versioning mode, rule and skill
  source modes, and the included and excluded rules and skills
- Do not symlink `CLAUDE.md` or `AGENTS.md`; generate their managed
  blocks from the selected rule source instead
- Read rule files from the first available source:
  - The target repository's `.agent-guidelines/rules` path
  - The target repository's `rules/` directory
  - The `rules/` directory from this guidelines repository
  - An installed rules source packaged with the skill
- If no rules source is available, skip rule assembly and report a
  warning
- Supported profiles include these rule files when available:
  - `minimal`:
    - `agent-conduct.md`
    - `git-workflow.md`
    - `git-messages.md`
    - `no-plans-on-main.md`
    - `merge-requests.md`
    - `development-attribution.md`
    - `configuration.md`
    - `testing.md`
    - `documentation.md`
  - `codebase`:
    - all `minimal` rules
    - `docstrings.md`
    - `dependencies.md`
    - `scripts.md`
    - `code-quality.md`
    - `engineering-judgment.md`
    - `environment-hygiene.md`
  - `released`:
    - all `codebase` rules
    - `backward-compatibility.md`
- Include these changelog and versioning rules by selected mode:
  - `changelog mode: none`: no changelog or versioning rules
  - `changelog mode: date`: `changelog-common.md`,
    `changelog-date.md`
  - `changelog mode: version`: `changelog-common.md`,
    `changelog-version.md`, `versioning-semver.md`,
    `backward-compatibility.md`
- Allow explicit include and exclude overrides:
  - `include rule <id>` adds `<id>.md` when available
  - `exclude rule <id>` removes `<id>.md` unless it is required for the
    selected changelog or versioning mode
- Apply rule selection in this order:
  - Start with the selected profile's rule list
  - Add changelog and versioning mode rules
  - Add explicit include-rule overrides
  - Remove explicit exclude-rule overrides
  - Keep mode-required rules
- Canonical rule order:
  - `agent-conduct.md`
  - `git-workflow.md`
  - `git-messages.md`
  - `no-plans-on-main.md`
  - `merge-requests.md`
  - `development-attribution.md`
  - `configuration.md`
  - `testing.md`
  - `documentation.md`
  - `docstrings.md`
  - `scripts.md`
  - `code-quality.md`
  - `engineering-judgment.md`
  - `environment-hygiene.md`
  - `dependencies.md`
  - `changelog-common.md`
  - `changelog-date.md`
  - `changelog-version.md`
  - `versioning-semver.md`
  - `backward-compatibility.md`
- Include any selected future rule files that are not in the canonical
  order alphabetically after known rules
- Use the source file's existing title as the heading for each included
  rule
- Do not rewrite, summarize, or otherwise change the rule text
- Report which rule files were included, skipped, or unavailable

## Per-Project Skills

- Install skills only when the user opts in with `include skill <id>`
  (`--include-skill` for the script); `exclude skill <id>` removes a
  skill from the selection
- Install selected skills into `.agents/skills/<skill>/` in the target
  repository, where the supported harnesses discover project skills
- Use the same source mode as rules unless the user overrides it
  (`--skills-source symlink|copy`)
- In symlink mode, link each skill directory to its canonical source
  and add `.agents/skills/` to `.git/info/exclude` so the links stay
  out of git
- In copy mode, copy the skill directory as a tracked project asset
- Leave a path in place and report it as skipped when it exists and is
  not what the selected mode would create (a symlink pointing
  elsewhere, a regular file, or a directory in symlink mode)
- Warn when a selected skill does not exist in the skills source

## Commit Template

- Create `.gittemplate` if it does not already exist
- Use `assets/gittemplate` as the template source
- Configure the repository to use it:

```bash
git config --local commit.template .gittemplate
```

- If `.gittemplate` already exists, leave the file unchanged and still
  ensure the local git config points to it
- Do not overwrite an existing user-managed commit template without asking

## Gitignore

- Create `.gitignore` if it does not already exist
- For an empty or unrecognized project, use `assets/gitignore-minimal`
  as the starting content

- If `.gitignore` already exists, leave it unchanged

## README

- Create `README.md` if it does not already exist
- If the project purpose can be inferred from existing files, include a
  short project description
- If the project purpose is unclear, create a minimal README with the
  directory name as the title
- If `README.md` already exists, leave it unchanged

## Changelog

Only when changelog maintenance is enabled:

- Create `CHANGELOG.md` if it does not already exist
- Use `assets/changelog-base.md` as the initial changelog content

- Do not add an empty `[Unreleased]` section or an empty dated section
  during initial setup
- If `CHANGELOG.md` already exists, leave it unchanged

## Initial Commit

Only when the skill initializes a new git repository:

- Create one initial commit after repository files are created and local
  configuration is applied
- Stage only project files that were created for the repository:
  - `.gittemplate`
  - `.gitignore`
  - `README.md`
  - `CHANGELOG.md` when changelog maintenance is selected
  - `.agent-guidelines/rules/` when copy mode is selected for a
    portable rule snapshot
  - `.agents/skills/` when skills are selected in copy mode
- Do not stage or commit local agent instruction files:
  - `CLAUDE.md`
  - `CLAUDE.local.md`
  - `AGENTS.md`
  - `.claude/`
  - `.codex/`
- Do not stage or commit local git configuration:
  - `.git/info/exclude`
  - `.git/hooks/`
- Do not stage or commit `opencode.json` or `.mcp.json` when they were
  treated as private local configuration
- Use this commit message:

```text
chore: initialize repository
```

- If there are no project files to commit, skip the initial commit and
  report why
- If the target repository already has commits, never create an initial
  commit

## Git Hooks

- Install or update local hooks only in the target repository's
  `.git/hooks` directory
- Create hook files when they do not exist
- Preserve existing hook content
- Start newly created hook files with `#!/bin/sh`
- Insert managed snippets from `assets/hooks/` by marker block into
  these hook files:
  - `pre-commit`: `pre-commit-main-branch`
  - `pre-commit`: `pre-commit-attribution`
  - `pre-commit`: `pre-commit-banned-phrases`
  - `commit-msg`: `commit-msg-attribution`
  - `commit-msg`: `commit-msg-banned-phrases`
  - `commit-msg`: `commit-msg-conventional`
  - `pre-push`: `pre-push-branch-name`
- Add each snippet only when its exact marker block is missing
- Replace an existing managed marker block only when the corresponding
  asset content changed
- Leave unknown or user-managed hook content in place before and after
  managed marker blocks
- Preserve the relative order of managed snippets within each hook file
- Ensure updated hook files are executable
- Do not install hooks globally or into other repositories

## Rerun and Idempotency

- Before writing any file, compare the intended content or managed block
  to the existing content
- Do not rewrite files that are already correct
- Do not duplicate local exclude patterns, config entries, hook snippets,
  or project rule blocks
- Do not replace user-managed content outside explicit marker blocks
- Treat an already-correct git config value as unchanged
- Treat an existing user-managed file as skipped when the skill cannot
  safely determine how to update it
- When replacing a managed marker block, preserve the surrounding file
  content and newline style when practical
- Track each operation as one of:
  - Created
  - Updated
  - Unchanged
  - Skipped
  - Warning

## Output Summary

At the end, print:

- Repository location
- Current branch
- Git `user.name` and `user.email`
- Selected profile:
  - minimal
  - codebase
  - released
- Selected changelog mode:
  - none
  - date
  - version
- Selected versioning mode:
  - none
  - semver
- Rule source mode:
  - symlink
  - copy
- Skill source mode:
  - symlink
  - copy
- Included rules and included skills, in their applied order
- Created files, hooks, config values, and commits
- Updated files, hooks, and config values
- Unchanged files, hooks, and config values
- Skipped files and the reason each was skipped
- Warnings and manual follow-up steps
