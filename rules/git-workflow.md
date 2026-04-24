# Git Workflow Rules

## How Work Builds Up

Think of development as composition from small pieces:

1. **A commit** is the smallest meaningful change — one function
   implemented, one bug fixed, one config option added. It should be
   describable in a single sentence and independently revertable.
2. **A branch** is a complete unit of work made up of many small
   commits — a feature, a component, a fix. It has a clear goal and is
   only merged when that goal is fully achieved.
3. **The project** is the sum of all merged branches on `main`. Each
   merge represents a completed, tested piece of work.

This is bottom-up composition. You don't need to plan every commit in
advance — you commit naturally as you work, whenever you've completed a
meaningful change. The discipline is in recognizing when you've done
enough for one commit and stopping to record it before moving on.

## Branching

- NEVER commit directly to the `main` branch — there are NO exceptions,
  including changelog cuts, version bumps, or other "bookkeeping"
  commits
- Create a new branch for every feature, fix, or change
- Use descriptive slash-prefixed branch names:
  `feat/description`, `fix/description`, `chore/description`
- Before creating a branch, choose the branch type from the work being
  done and verify that the name matches the documented pattern. If the
  branch name does not fit, stop and choose a better name before running
  `git checkout -b`.
- Only merge back to `main` when the work for that branch is fully
  complete
- Always merge with `--no-ff` to create an explicit merge commit, even
  when a fast-forward is possible. This preserves the branch as a
  visible grouping of related commits in the history and makes it
  possible to revert an entire feature with a single `git revert`.
- If the project maintains a `CHANGELOG.md`, keep changelog edits on the
  branch that made the work — never as a follow-up commit on main. For
  versioned projects, the `[Unreleased]` to release cut happens on the
  release branch. For date-based projects, write entries directly into
  that day's dated section. See `changelog-common.md`,
  `changelog-date.md`, and `changelog-version.md` for details.

## Commits

See `git-messages.md` for commit message, amendment, and merge commit
message formatting rules.

### Commit rhythm

A feature branch should have MANY small commits, not one or two large
ones. The natural rhythm when building something:

1. **Interface first** — define the header / API / types. Commit.
2. **Implement in logical groups** — don't implement everything then
   commit. Group related functions (e.g., all sensor-related builders,
   all actuator-related builders) and commit each group. A 500-line
   source file should never land in a single commit.
3. **Tests** — commit as their own unit per logical group, or as a
   cohesive set if they're small.

STOP and commit after completing each meaningful change before moving on
to the next one. A meaningful change is something you can describe in a
single sentence: one function added, one handler implemented, one test
written, one config option wired up.

When in doubt, commit more often rather than less often. Err on the side
of too many small commits — they can be squashed later, but a monolithic
commit can't be split after the fact.

### What NOT to do

- NEVER have more than 3-4 modified files uncommitted at once — if you
  do, you've gone too far without committing
- Do NOT batch unrelated changes into a single commit
- Do NOT implement an entire source file and commit it all at once —
  break it into logical groups
- If you find yourself writing "and" in a commit message subject, it
  should probably be two commits
- The revert test: every commit should be independently revertable
  without undoing unrelated work
- If a new change belongs to a different scope than the current branch,
  stop and put it on a separate branch unless it is required to complete
  the current branch safely

## Merge Readiness

- A branch must not be merged if it breaks behavior that already exists
  on `main`
- If a branch intentionally replaces existing behavior, it must include
  the replacement before it is merged
- Documentation must describe behavior that exists on the branch being
  merged, not planned future behavior
- Run the relevant checks for the project before merging; if no
  automated checks exist yet, review the changed files manually
- Treat project hooks as part of the workflow. Understand and resolve
  hook failures before continuing; do not bypass hooks unless the team
  has agreed that the hook is wrong for the current change.
- Before merging, review the branch diff against the branch goal.
  Confirm that the diff is scoped, changelog entries are correct,
  temporary files are removed, generated files are intentional, and no
  unrelated changes were included.
- For versioned projects, check whether the branch warrants a release
  and either recommend the appropriate version bump or state that no
  release is needed
- After each merge, `main` should represent a coherent project state
  that can be used as the starting point for the next branch

## After Merge

- Delete the local feature branch after it has been merged into `main`
- Use safe deletion (`git branch -d <branch>`) so Git refuses if the
  branch was not fully merged
- Do not use force deletion (`git branch -D <branch>`) unless you
  intentionally want to discard unmerged branch history
- After merging, verify `git status`, confirm the merged branch was
  deleted, remove temporary files, and check recent history to ensure
  the merge commit represents the intended branch

## Publishing

- Push feature branches when work should be backed up, reviewed, or
  shared
- Push `main` only after it represents a coherent merged state

## Local and Generated Files

- Local scratch files, generated candidate lists, temporary exports, and
  machine-specific artifacts must not be committed unless they are part
  of the project contract
- Add local-only files to `.git/info/exclude` when the ignore rule is
  personal to one checkout; add them to a tracked ignore file only when
  the pattern should apply to everyone
