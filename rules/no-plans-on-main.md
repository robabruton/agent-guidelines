---
when: always
load: always
summary: >-
  Permanent project history must read as a record of work that
  happened, not work that is intended. Forbids speculative planning
  content — plans for later phases, lists of unfinished work,
  forward-looking promises — in any tracked file, commit message,
  pull request description, merge commit body, or branch name.
  Includes a banned-phrase checklist run before staging, a matching
  pre-commit guard installed by `project-setup.sh`, and a pointer to
  where plans legitimately belong (durable agent memory, untracked
  `local/` files, scratch branches).
---
# No Plans in Permanent History

## Hard Constraints

- Never let forward-looking content — roadmaps, TODO lists, "phase N"
  plans, "what's next" notes, promises of later work — reach any
  tracked file, commit message, pull/merge request description, merge
  commit body, or branch name.
- Scan those five artifacts against the banned-phrase list below
  before the first commit, every time.
- Keep plans in a durable agent memory store, an untracked `local/`
  file, or a scratch branch that never merges.
- Write tracked documentation in the present tense, describing only
  behavior that exists.

The sections below give the rationale and the details behind each
constraint. Permanent project history — every commit message, every file on the
default branch, every release artifact — must read as a record of
work that *happened*, not work that is *intended*. Speculative
content (roadmaps, TODO lists, "phase N" plans, "what's next" notes,
forward-looking promises) must never land in that history. The
project should always look intentional, with documentation that
describes behavior that actually exists; a tracked roadmap invites
drift when priorities shift, and the discrepancy makes the work look
planned-but-undone.

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

## Banned-Phrase Pre-Stage Checklist

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

Phrases to catch (case-insensitive):

- "will be added", "will land", "will follow", "coming soon", "next
  session", "future work", "roadmap"
- "followup", "follow-up", "followups", "follow-ups", "next-step",
  "next-steps", "to-do", "upcoming" (and any other "more work after
  this" phrasing — conversational language flows into branch names
  without scrutiny)
- "not yet", "does not yet", "until X migrates", "when X needs"
- "first caller", "first migration", "first concrete" (and similar
  "first <noun>" constructions that imply more is planned)
- "TODO" / "FIXME" markers for unimplemented work in tracked source
- Named hypothetical alternatives ("X or Y later", "we will swap to
  ...")

## Allowed

- Descriptions of what currently exists and how it behaves.
- A standard `[Unreleased]` changelog heading while real changes
  accumulate for a release.
- A changelog entry describing work that just landed.

When in doubt, rewrite the sentence to describe the present, not the
future: "Implements X" instead of "First implementation of X; Y will
follow." "All access goes through the store" instead of "Swapping
the backend later leaves this unchanged."

Run the scan before the first commit, every time. Phrasing that
reaches a shared default branch can only be removed by history
rewriting and coordinated force-pushes; catching it after the fact
is the costly path.
