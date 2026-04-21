---
name: project-setup
description: Initialize or update a repository with project rules, git hooks, commit standards, and agent configuration
---

Set up a project repository with reusable development standards. This
skill is idempotent: it checks what already exists, adds missing setup,
and avoids overwriting user-managed files.

Use this skill for both new repositories and existing repositories that
need project rules, git configuration, local hooks, or agent instruction
files refreshed.

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
- If `CHANGELOG.md` exists:
  - Treat changelog maintenance as enabled
  - Infer versioned changelog mode if it contains `## [Unreleased]` or
    version headings such as `## [1.2.3] - YYYY-MM-DD`
  - Infer date-based changelog mode if it contains date headings such as
    `## 2026-04-21` and no version headings
  - If the format is mixed or unclear, summarize what was found and ask
    the user which mode to use
- If `CHANGELOG.md` does not exist:
  - Ask whether the project should maintain a changelog
  - If yes, create a base `CHANGELOG.md`
  - If no, omit changelog rules and do not create `CHANGELOG.md`
- Inspect version indicators such as `package.json`, `pyproject.toml`,
  `Cargo.toml`, `go.mod`, `VERSION`, and tags matching `vX.Y.Z`
- Use version files and version-like tags as evidence that the project
  may be versioned, but do not create a changelog solely from that
  evidence without user confirmation
- Ask whether the project has releases, users, packages, APIs, or other
  versioned artifacts when versioning cannot be inferred confidently
- Existing changelog structure takes priority over versioning guesses
- Print a short summary of the selected options before continuing

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
- Read rule files from the first available source:
  - The target repository's `rules/` directory
  - The `rules/` directory from this guidelines repository
  - An installed rules source packaged with the skill
- If no rules source is available, skip rule assembly and report a
  warning
- Always include these rule files when available:
  - `git-workflow.md`
  - `docstrings.md`
  - `development-attribution.md`
  - `testing.md`
  - `documentation.md`
  - `configuration.md`
  - `scripts.md`
  - `dependencies.md`
  - `backward-compatibility.md`
- Include `changelog.md` only when changelog maintenance is selected
- Include `versioning.md` only when versioned project mode is selected
- Keep the assembled rules in the order listed above
- Use the source file's existing title as the heading for each included
  rule
- Do not rewrite, summarize, or otherwise change the rule text
- Report which rule files were included, skipped, or unavailable

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
  - `commit-msg`: `commit-msg-attribution`
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

## Output Summary

At the end, print:

- Repository location
- Current branch
- Git `user.name` and `user.email`
- Whether versioning rules were selected
- Whether changelog maintenance was selected
- What was created, updated, skipped, or left unchanged
- Any warnings or manual follow-up steps
