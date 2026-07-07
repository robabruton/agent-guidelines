---
when: always
load: always
summary: >-
  Composition model for development: a commit is the smallest
  meaningful change, a branch is a complete unit of work made up of
  many small commits, the project is the sum of all merged branches
  on `main`. Covers branch naming, the commit rhythm (interface
  first, implementation in logical groups, tests as their own units),
  merge-readiness, the always-merge-with-`--no-ff` convention, and
  cleanup after merge. The rule exists so history reflects how work
  actually built up rather than collapsing into monolithic commits.
---
# Git Workflow Rules

## Hard Constraints

- Never author work commits directly on `main`; only `--no-ff` merge
  commits originate there, with no bookkeeping exceptions.
- Create a slash-prefixed branch (`feat/`, `fix/`, `chore/`) for every
  change, named from the work being done.
- Merge only when the branch's work is fully complete, always with
  `--no-ff`.
- Commit each meaningful change as it lands; never leave more than 3-4
  modified files uncommitted.
- One scope per commit; every commit must be independently revertable.
- Keep changelog edits on the branch that made the work, never as a
  follow-up commit on `main`.
- Run the project's checks and resolve hook failures before merging;
  do not bypass hooks unilaterally.
- When `main` is protected, push the branch and merge through a
  pull/merge request; never merge locally and push.
- After merge, delete the branch with `git branch -d` and verify
  status and history.
- Never commit local scratch or generated files that are not part of
  the project contract.

The rationale and detail behind each constraint:

## How Work Builds Up

Development composes bottom-up from small pieces:

1. **A commit** is the smallest meaningful change — one function
   implemented, one bug fixed, one config option added. It should be
   describable in a single sentence.
2. **A branch** is a complete unit of work made up of many small
   commits — a feature, a component, a fix — merged only when its
   goal is fully achieved.
3. **The project** is the sum of all merged branches on `main`. Each
   merge represents a completed, tested piece of work.

## Branching

- "No bookkeeping exceptions" includes changelog cuts and version
  bumps. The pre-commit main-branch guard installed by
  `project-setup.sh` allows merge commits on `main` while blocking
  every other commit.
- Name the branch from the work being done, not from where the
  repository happens to be checked out, and verify the name matches
  the documented pattern before creating it. Before starting new
  work, confirm the current branch's scope covers it; if not, create
  a new branch rather than piling distinct work onto a branch named
  for a different scope.
- `--no-ff` applies even when a fast-forward is possible: the
  explicit merge commit preserves the branch as a visible grouping in
  history and makes a whole feature revertable with a single
  `git revert`.
- See `changelog-common.md`, `changelog-date.md`, and
  `changelog-version.md` for changelog section formats and the
  release cut.

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

### Commit scope

- Do NOT batch unrelated changes into a single commit. If a change
  belongs to a different scope than the current branch, put it on a
  separate branch unless it is required to complete this branch
  safely.
- If you find yourself writing "and" in a commit message subject, it
  should probably be two commits.
- The revert test: reverting any one commit must not undo unrelated
  work.

## Merge Readiness

- A branch must not break behavior that already exists on `main`; if
  it intentionally replaces existing behavior, it must include the
  replacement before it is merged
- Documentation must describe behavior that exists on the branch
  being merged, not planned future behavior
- If no automated checks exist yet, review the changed files manually
- Bypassing a hook is a team decision that the hook is wrong for the
  current change, never a way around a failure you have not
  understood
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

Push the branch, open a pull/merge request, wait for required checks
to pass, and merge through the platform. Afterwards, confirm the
merge landed with the intended commit body — a body lost at merge
time is on permanent, protected history and is costly to correct.

## After Merge

- Safe deletion (`git branch -d`) makes Git refuse if the branch was
  not fully merged; use force deletion (`-D`) only to intentionally
  discard unmerged branch history
- Verify `git status`, confirm the merged branch was deleted, remove
  temporary files, and check recent history to ensure the merge
  commit represents the intended branch

## Publishing

- Push feature branches when work should be backed up, reviewed, or
  shared; push `main` only after it represents a coherent merged
  state

## Local and Generated Files

- Local scratch files, generated candidate lists, temporary exports,
  and machine-specific artifacts are not part of the project contract
- Add local-only ignore rules to `.git/info/exclude` when they are
  personal to one checkout; use a tracked ignore file only for
  patterns that should apply to everyone
