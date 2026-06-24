---
when: always
load: always
---
# No Plans in Permanent History

Permanent project history — every commit message, every file on the
default branch, every release artifact — must read as a record of work
that *happened*, not work that is *intended*. Speculative content
(roadmaps, TODO lists, "phase N" plans, "what's next" notes,
forward-looking promises) must never land in that history.

The goal is that the project always looks intentional and that its
documentation describes behavior that actually exists. Roadmaps in the
tracked tree invite the project to drift from its own documentation when
priorities shift; the discrepancy then makes the work look
planned-but-undone.

## Where Plans Belong Instead

Planning is legitimate and necessary — it just lives outside permanent
history:

- A durable agent memory store (see the `agent-memory` skill).
- An untracked working file under a `local/` subdirectory that is added
  to a personal ignore mechanism (e.g. the VCS's local exclude file),
  not the shared, tracked ignore file.
- A branch that is used as personal scratch space and never merged.

Reserve top-level directories (`docs/`, `scripts/`, etc.) for real
tracked content. Isolate local-only material one level deeper under
`local/` so the top-level directory still holds shippable work.

Organize files inside `local/` to mirror the project's tracked layout
— `local/plans/`, `local/docs/`, `local/scripts/`, and so on. The
mirror makes the local equivalent of any tracked path easy to find,
keeps a single `local/` entry in the personal ignore mechanism, and
avoids ad-hoc top-level scratch directories that look like project
content.

## Banned-Phrase Pre-Stage Checklist

Before staging any file that will land on the default branch, and before
publishing any commit message, pull/merge request description, or merge
commit body, scan the content for forward-looking or provenance-revealing
phrasing. If any appears, rewrite to describe the present before
proceeding.

Treat these five artifacts as separate scans — the merge commit body is
written later than the branch work and is the one most often missed,
and the branch name is the one most often overlooked because it is
chosen before any commit exists:

1. Staged file content (source, docs, comments, config).
2. Commit messages.
3. The pull/merge request description.
4. The merge commit body.
5. The branch name itself, before `git switch -c` or any equivalent
   creation command. A branch name lands on the default branch as the
   merge commit's subject line (`Merge branch '<name>'`), so it is
   permanent history and must pass the same scan.

Phrases to catch (case-insensitive):

- "will be added", "will land", "will follow", "coming soon", "next
  session", "future work", "roadmap"
- "followup", "follow-up", "followups", "follow-ups", "next-step",
  "next-steps", "to-do", "upcoming" (and any other "more work after
  this" phrasing — these slip into branch names easily because
  conversational language flows into branch names without scrutiny)
- "not yet", "does not yet", "until X migrates", "when X needs"
- "first caller", "first migration", "first concrete" (and similar
  "first <noun>" constructions that imply more is planned)
- "TODO" / "FIXME" markers for unimplemented work in tracked source
- Named hypothetical alternatives ("X or Y later", "we will swap to ...")

## Allowed

- Descriptions of what currently exists and how it behaves.
- A standard `[Unreleased]` changelog heading while real changes
  accumulate for a release.
- A changelog entry describing work that just landed.

When in doubt, rewrite the sentence to describe the present, not the
future: "Implements X" instead of "First implementation of X; Y will
follow." "All access goes through the store" instead of "Swapping the
backend later leaves this unchanged."

## Why This Is Hard to Retrofit

Forward-looking phrasing that reaches a protected default branch is
expensive to remove — it requires history rewriting, which on a shared
branch means coordinated force-pushes and is risky. The cheap fix is the
pre-stage scan above, run before the first commit, every time. Catching
it after the fact is the costly path.
