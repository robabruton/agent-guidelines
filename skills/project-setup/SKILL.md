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
- If the target directory does not exist, create it only when it is not
  beneath an existing repository worktree
- Require an existing Git target to be the physical worktree root, not a
  subdirectory
- Resolve and print the absolute target path before making changes

## Preflight

- Verify `git` is available
- Reject ambient Git repository and object-store redirect variables so all
  Git reads and writes remain tied to the target
- Verify `user.name` and `user.email` in the target repository's Git
  configuration context, which applies local, global, and system precedence
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
- Resolve one default branch for setup state and both branch-policy hooks in
  this order:
  - an explicit `--default-branch <name>` selection
  - the checksum-owned stored setup value
  - the symbolic branch of an unborn repository
  - one locally recorded remote default whose branch exists locally
  - the sole local branch
  - the checked-out `main` or `master` branch when several local branches
    exist
- Stop and require `--default-branch` when the remaining evidence is absent,
  conflicting, or points only to a typed work branch
- Validate the selected name as a Git branch and require an explicit name to
  exist in an existing repository
- Never rename or check out a branch automatically
- Use `main` for a new repository unless `--default-branch` selects another
  valid name
- If the target is not a Git repository, initialize its Git metadata in a
  recovery directory beside the target using the selected branch:

```bash
git --git-dir=<recovery-dir>/git --work-tree=<target> \
  init --initial-branch=<default-branch>
```

- Install the completed staged Git directory as `<target>/.git` only after all
  repository setup succeeds
- If the final move or verification fails, roll back target files and retain a
  complete staged repository at the reported recovery path
- If the installed Git directory cannot be restored to its staged path,
  preserve both the installed directory and its transaction recovery copy
  instead of deleting uncertain state
- If the target is already a Git repository, do not reinitialize it
- Report whether the repository was created or already existed

## Local Git Excludes

- Add local-only agent and tool files to `.git/info/exclude`
- Create `.git/info/exclude` if it does not already exist
- Append only missing exclude patterns and preserve existing user entries
- Record only exclude lines created by this run in the Git directory's
  `agent-guidelines/ownership-v1` state; an identical existing line
  remains user-managed
- Do not add these patterns to `.gitignore`, because these files are
  local agent configuration rather than project artifacts
- Always exclude:
  - `CLAUDE.md`
  - `CLAUDE.local.md`
  - `AGENTS.md`
  - `.codex/`
  - `.agent-guidelines/config`
- Exclude `.claude/` unless selected Claude project skills use tracked copy
  mode
- Exclude `.agent-guidelines/rules` when it is a symlink to a local
  canonical rules directory
- Exclude `opencode.json` only when it is private local configuration,
  not when the project intentionally tracks it as a shared artifact
- Exclude `.mcp.json` only when it is private local configuration, not
  when the project intentionally tracks it as a shared artifact
- If `opencode.json` or `.mcp.json` already exists and is tracked by git,
  leave it tracked and report that it was skipped

## Project Rule Assembly

- Accept repeatable `--harness claude|codex|opencode|pi` selections
- Create or update `CLAUDE.md` when Claude Code is selected
- Create or update `AGENTS.md` when Codex, OpenCode, or Pi is selected
- Create or update both files when no harness is selected, preserving
  compatibility for projects without project-local skills
- Remove only the managed block from a context file made unnecessary by an
  explicit selection change
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
- Build one self-contained compact block independent of global setup:
  - include the authoritative hard constraints from every selected
    always-loaded rule
  - include a complete trigger and path router for all selected rules
  - direct the harness to read every triggered rule completely from
    `.agent-guidelines/rules/<rule>.md`
- Reject a generated managed policy above 12,288 bytes before mutation
- Reject a candidate context file above 24,576 bytes before mutation,
  including its preserved content, generated preamble, and managed block
- Use `compact` as the canonical `--context-rules` value
- Accept `auto`, `full`, and `trimmed` as compatibility values and migrate
  them to `compact`
- Record `context_rules=compact` in `.agent-guidelines/config`
- Keep rule source files separate from generated agent instruction files
- Prefer a symlinked rule source so projects can refresh generated
  instructions from updated central rules
- Use `.agent-guidelines/rules` in the target repository as the preferred
  project-local rule source path
- If `.agent-guidelines/rules` does not exist and symlink mode is
  selected, create it as a symlink to the canonical `rules/` directory
- In copy mode, track the rule snapshot in `.agent-guidelines/rules` and add
  `POLYFORM-NONCOMMERCIAL.txt` from the canonical notice asset
- Display the canonical PolyForm Noncommercial 1.0.0 notice and terms URL
  before performing any copy-mode mutation in the target repository
- Accept only the exact canonical symlink or an exact licensed snapshot;
  add a missing notice only when every other entry matches the canonical
  source, and stop without mutation on every other existing path
- Treat `.agent-guidelines/config` as checksum-owned local setup state in a
  strict, versioned, non-executable data format
- Record `schema=1`, the selected profile, changelog and context modes, rule
  and skill source modes, harnesses, default branch, and repeated include and
  exclude records for rules and skills; derive versioning mode from changelog
  mode
- Record `harness=none` for an empty selection; migrate skill-bearing state
  without harness metadata to all supported consumers
- Load an existing state file only when its ownership record contains the
  exact current checksum; reject malformed keys, invalid values, duplicate
  records, unsupported schemas, NUL data, symlinks, and changed or unowned
  state before mutation
- Migrate an exact checksum-owned versionless setup file to schema 1 while
  preserving its selections
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
    - `debugging.md`
    - `error-handling.md`
    - `engineering-judgment.md`
    - `environment-hygiene.md`
    - `performance.md`
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
  - `debugging.md`
  - `error-handling.md`
  - `engineering-judgment.md`
  - `environment-hygiene.md`
  - `performance.md`
  - `dependencies.md`
  - `changelog-common.md`
  - `changelog-date.md`
  - `changelog-version.md`
  - `versioning-semver.md`
  - `backward-compatibility.md`
- Include selected rule files absent from the canonical order alphabetically
  after known rules
- Use the source file's existing title as the heading for each included
  rule
- Do not rewrite, summarize, or otherwise change the rule text
- Report which rule files were included, skipped, or unavailable

## Per-Project Skills

- Treat globally installed skills as sufficient for normal local use
- Install a project-local skill only when the user opts in for a portable
  copy or pinned snapshot with `include skill <id>` (`--include-skill` for
  the script)
- Require at least one explicit harness selection whenever project-local
  skills are selected; do not infer consumers from installed tools
- Use `exclude skill <id>` (`--exclude-skill`) to cancel a matching
  project-local selection in the same invocation; it does not hide a globally
  installed skill
- Install Claude Code skills into `.claude/skills/<skill>/`
- Install Codex and Pi skills into `.agents/skills/<skill>/`
- Install OpenCode skills into `.claude/skills/<skill>/` when Claude Code is
  also selected and neither Codex nor Pi is selected; otherwise use
  `.agents/skills/<skill>/`
- Install both trees when the complete selection requires both, using the
  same canonical source for each
- Use the same source mode as rules unless the user overrides it
  (`--skills-source symlink|copy`)
- In symlink mode, link each skill directory to its canonical source and
  locally exclude the applicable skill trees so the links stay out of git
- In copy mode, copy the skill directory as a tracked project asset and add
  `POLYFORM-NONCOMMERCIAL.txt` from the canonical notice asset
- Accept only the exact canonical symlink or an exact licensed copy; add a
  missing notice only when every other entry matches the canonical source,
  and stop without mutation on every other existing path
- Warn when a selected skill does not exist in the skills source

## Commit Template

- Create `.gittemplate` if it does not already exist
- Use `assets/gittemplate` as the template source
- Configure the repository to use it:

```bash
git config --local commit.template .gittemplate
```

- If `.gittemplate` already exists, leave the file unchanged
- Set `commit.template` only when it is unset or already equals
  `.gittemplate`; stop without mutation when it names a user-managed
  template
- Record ownership only when setup creates the local config value;
  matching legacy configuration remains user-managed

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

- Create one initial commit in the staged Git directory after repository files
  are created and local configuration is applied
- Stage only project files that were created for the repository:
  - `.gittemplate`
  - `.gitignore`
  - `README.md`
  - `CHANGELOG.md` when changelog maintenance is selected
  - `.agent-guidelines/rules/` when copy mode is selected for a
    portable rule snapshot
  - `.claude/skills/` when selected skills use Claude copy mode
  - `.agents/skills/` when skills are selected in copy mode
- Do not stage or commit local agent instruction files:
  - `CLAUDE.md`
  - `CLAUDE.local.md`
  - `AGENTS.md`
- Do not stage other `.claude/` or `.codex/` content
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
- If an existing repository has an unborn branch and an empty index, configure
  it without creating a commit
- If an existing unborn repository has staged content, stop before mutation
  and leave its index unchanged
- Use the Git identity resolved from the target configuration for both author
  and committer metadata

## Git Hooks

- Resolve the target's effective hooks directory and require it to remain
  beneath that repository's absolute Git directory
- Reject absolute, shared, escaping, or linked-worktree-relative
  `core.hooksPath` values whose effective hook path is outside that boundary
- Install or update local hooks only in the validated target hooks directory
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
- Make the pre-commit default-branch guard and pre-push branch-name guard read
  the same `default_branch=` value from `.agent-guidelines/config` at runtime
- Make both branch-policy hooks fail closed when the state file is missing,
  linked, duplicated, or contains an invalid branch name

## Removal

- `--remove` strips exact managed hook and context blocks, exact canonical
  rule and skill symlinks, and local state carrying a valid ownership
  record
- Remove owned `.git/info/exclude` lines, `commit.template`, and
  `.agent-guidelines/config` only when their current values still match
  the recorded state; stop without mutation on a mismatch
- Leave identical legacy exclude lines, config values, and configuration
  files without ownership records in place
- Delete a hook file only when nothing but a shebang and blank lines
  remains, and delete a context file only when nothing but its generated
  preamble remains
- Leave project artifacts in place: `.gittemplate`, `.gitignore`,
  `README.md`, `CHANGELOG.md`, commits, tracked rule or skill
  copies, and any user content in hook files or context files
- Removal honors `--dry-run` and is safe to run repeatedly

## Rerun and Idempotency

- With no selection options, reload the exact checksum-owned setup state and
  preserve its scalar values, include and exclude records, and source modes
- Apply explicit scalar and selection options only to the named setting;
  exclusion wins when the same identifier is both included and excluded
- Switch between symlink and copy modes only for an exact recorded managed
  object, and reconcile only the corresponding owned local exclude entry
- Before writing any file, compare the intended content or managed block
  to the existing content
- Do not rewrite files that are already correct
- Do not duplicate local exclude patterns, config entries, hook snippets,
  or project rule blocks
- Do not replace user-managed content outside explicit marker blocks
- Treat an already-correct git config value as unchanged
- Stop before mutation when a managed destination has ambiguous ownership
  or conflicts with the selected source mode
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
- Selected default branch policy
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
- Selected harnesses and the corresponding context mode for each file
- Included rules and included skills, in their applied order
- Created files, hooks, config values, and commits
- Updated files, hooks, and config values
- Unchanged files, hooks, and config values
- Skipped files and the reason each was skipped
- Warnings and required manual actions
