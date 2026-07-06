---
when: always
load: always
---
# Git Workflow Rules

## How Work Builds Up

Development composes bottom-up from small pieces:

1. **A commit** is the smallest meaningful change — one function
   implemented, one bug fixed, one config option added. It should be
   describable in a single sentence and independently revertable.
2. **A branch** is a complete unit of work made up of many small
   commits — a feature, a component, a fix — merged only when its
   goal is fully achieved.
3. **The project** is the sum of all merged branches on `main`. Each
   merge represents a completed, tested piece of work.

## Branching

- NEVER author work commits directly on the `main` branch — there are
  NO exceptions for changelog cuts, version bumps, or other
  "bookkeeping" commits. `--no-ff` merge commits are the only commits
  that originate on `main`, and the pre-commit main-branch guard
  installed by `project-setup.sh` allows them while blocking every
  other commit on `main`.
- Create a new branch for every feature, fix, or change, with a
  descriptive slash-prefixed name: `feat/description`,
  `fix/description`, `chore/description`
- Name the branch from the work being done, not from where the
  repository happens to be checked out, and verify the name matches
  the documented pattern before creating it. Before starting new
  work, confirm the current branch's scope covers it; if not, create
  a new branch rather than piling distinct work onto a branch named
  for a different scope.
- Merge back to `main` only when the branch's work is fully complete,
  and always with `--no-ff`, even when a fast-forward is possible.
  The explicit merge commit preserves the branch as a visible
  grouping in history and makes a whole feature revertable with a
  single `git revert`.
- If the project maintains a `CHANGELOG.md`, keep changelog edits on
  the branch that made the work — never as a follow-up commit on
  main. See `changelog-common.md`, `changelog-date.md`, and
  `changelog-version.md` for section formats and the release cut.

## Commits

See `git-messages.md` for commit message, amendment, and merge commit
message formatting rules.

### Commit rhythm

A feature branch should have MANY small commits, not one or two large
ones. The natural rhythm when building something:

1. **Interface first** — define the header / API / types. Commit.
2. **Implement in logical groups** — group related functions (e.g.,
   all sensor-related builders) and commit each group rather than
   implementing everything and committing once. A 500-line source
   file should never land in a single commit.
3. **Tests** — commit as their own unit per logical group, or as a
   cohesive set if they're small.

Commit naturally as you work: STOP and record each meaningful change
before moving to the next — one function added, one handler
implemented, one test written, one config option wired up. When in
doubt, commit more often: small commits can be squashed later, but a
monolithic commit can't be split after the fact.

Let commits emerge from the work. Describing its shape (interface
first, then implementation groups, then tests) is fine, but do NOT
pre-plan a numbered commit list ("commit 1 will be X, six total") —
the count falls out of the work naturally, and a counted list fights
letting history reflect what actually happened.

### What NOT to do

- NEVER have more than 3-4 modified files uncommitted at once
- Do NOT batch unrelated changes into a single commit. If a change
  belongs to a different scope than the current branch, put it on a
  separate branch unless it is required to complete this branch
  safely.
- If you find yourself writing "and" in a commit message subject, it
  should probably be two commits
- The revert test: every commit should be independently revertable
  without undoing unrelated work

## Merge Readiness

- A branch must not break behavior that already exists on `main`; if
  it intentionally replaces existing behavior, it must include the
  replacement before it is merged
- Documentation must describe behavior that exists on the branch
  being merged, not planned future behavior
- Run the relevant checks for the project before merging; if no
  automated checks exist yet, review the changed files manually
- Treat project hooks as part of the workflow. Understand and resolve
  hook failures before continuing; do not bypass hooks unless the
  team has agreed that the hook is wrong for the current change.
- Before merging, review the branch diff against the branch goal:
  the diff is scoped, changelog entries are correct, temporary files
  are removed, generated files are intentional, and no unrelated
  changes were included
- For versioned projects, check whether the branch warrants a release
  and either recommend the appropriate version bump or state that no
  release is needed
- After each merge, `main` should represent a coherent project state
  that can be used as the starting point for the next branch

## When the Default Branch Is Protected

If `main` is protected so direct pushes are rejected, never merge
locally and then try to push. Push the branch, open a pull/merge
request, wait for required checks to pass, and merge through the
platform. Afterwards, confirm the merge landed with the intended
commit body — a body lost at merge time is on permanent, protected
history and is costly to correct.

## After Merge

- Delete the local feature branch with safe deletion
  (`git branch -d <branch>`) so Git refuses if it was not fully
  merged; use force deletion (`-D`) only to intentionally discard
  unmerged branch history
- Verify `git status`, confirm the merged branch was deleted, remove
  temporary files, and check recent history to ensure the merge
  commit represents the intended branch

## Publishing

- Push feature branches when work should be backed up, reviewed, or
  shared; push `main` only after it represents a coherent merged
  state

## Local and Generated Files

- Local scratch files, generated candidate lists, temporary exports,
  and machine-specific artifacts must not be committed unless they
  are part of the project contract
- Add local-only ignore rules to `.git/info/exclude` when they are
  personal to one checkout; use a tracked ignore file only for
  patterns that should apply to everyone
