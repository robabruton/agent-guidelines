---
when: always
load: always
summary: >-
  Permanent project history must read as a record of work that
  happened, not work that is intended. Forbids speculative planning
  content — plans for later phases, lists of unfinished work,
  forward-looking promises — in any tracked file, commit message,
  pull request description, merge commit body, or branch name.
  Automatic hooks reject explicit promises and unfinished-work
  markers; contextual wording remains a manual review decision.
---
# No Plans in Permanent History

## Hard Constraints

- Never let forward-looking content — roadmaps, TODO lists, "phase N"
  plans, "what's next" notes, promises of later work — reach any
  tracked file, commit message, pull/merge request description, merge
  commit body, or branch name.
- Scan those five artifacts for planned work before the first commit,
  every time; hooks cover only the high-confidence forms below.
- Keep plans in a durable agent memory store, an untracked `local/`
  file, or a scratch branch that never merges.
- Write tracked documentation in the present tense, describing only
  behavior that exists.

Permanent history is every commit message, every file on the default
branch, every release artifact. The project should always look
intentional: a tracked plan invites drift when priorities shift, and
the discrepancy makes the work look planned-but-undone. Hooks installed
by `project-setup.sh` reject explicit forms on the surfaces they guard;
contextual review still applies to every permanent artifact.

## Where Plans Belong Instead

Planning is legitimate and necessary — it just lives outside
permanent history:

- A durable agent memory store (see the `agent-memory` skill).
- An untracked working file under `local/`, covered by a personal
  ignore mechanism (the VCS's local exclude file), never the shared
  tracked ignore file. Keep top-level directories (`docs/`,
  `scripts/`) for real tracked content, and organize `local/` to
  mirror the tracked layout (`local/plans/`, `local/docs/`,
  `local/scripts/`) so the local counterpart of any tracked path is
  easy to find and one `local/` ignore entry covers everything.
- A branch that is used as personal scratch space and never merged.

## Automatic Checks

The staged-content and commit-message guards reject these
high-confidence forms, case-insensitively:

- "will be added", "will land", "will follow", "coming soon",
  "next session", and "future work"
- "we plan to", "we intend to", and "planned for"
- standalone `TODO` and `FIXME` markers

The branch guard rejects the same explicit promises plus invalid
branch prefixes. Only the canonical rule itself is exempt from staged
phrase scanning, at exactly `rules/no-plans-on-main.md` or
`.agent-guidelines/rules/no-plans-on-main.md`.

## Manual Review

Scan these five artifacts separately for forward-looking or
provenance-revealing phrasing before they become permanent, and
rewrite to describe the present before proceeding:

1. Staged file content (source, docs, comments, config).
2. Commit messages.
3. The pull/merge request description.
4. The merge commit body — written later than the branch work and
   the scan most often missed.
5. The branch name, before `git switch -c` or any equivalent
   creation command — chosen before any commit exists, so easily
   overlooked, yet it lands on the default branch as the merge
   commit's subject (`Merge branch '<name>'`).

Words such as "roadmap", "follow-up", "upcoming", "not yet", "first",
and "later" require context; they are not automatic failures. Reject
them when they promise, schedule, or inventory unfinished work. Allow
them when they accurately describe current behavior, compatibility,
history, or reviewer attention without promising another change.

## Allowed

- Descriptions of what currently exists and how it behaves.
- Factual current limitations and deprecation or removal contracts.
- Reviewer notes grounded in the current change.
- Functional integration language and factual changelog transitions.
- A standard `[Unreleased]` changelog heading while real changes
  accumulate for a release.
- A changelog entry describing work that just landed.

When in doubt, rewrite the sentence to describe the present, not the
future: "Implements X" instead of "First implementation of X; Y will
follow." "All access goes through the store" instead of "Swapping
the backend later leaves this unchanged."

Phrasing that reaches a shared default branch can only be removed by
history rewriting and coordinated force-pushes; catching it after
the fact is the costly path.
