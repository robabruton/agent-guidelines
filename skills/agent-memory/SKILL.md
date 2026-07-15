---
name: agent-memory
description: Maintain a durable, file-based memory store across sessions — decide what is worth remembering, write typed point-in-time entries, keep a lean router index, organize into load tiers that scale without bloating context, and recall the right entries for a task.
when_to_use: Use when the user asks you to remember or save something, when a decision/constraint/correction is settled that would be costly to rediscover, at session start to recall what is relevant, at session end to record handoff state, or when the memory store has grown large enough that loading it costs too much context and needs reorganizing.
argument-hint: "[remember <fact> | recall <topic> | organize | review]"
---

Maintain a durable, file-based memory that survives across sessions so a
project accumulates institutional knowledge instead of relearning it each
time. This skill is the procedure for four operations on that store:
**decide → write → organize → recall**.

This skill is store-agnostic. The host tool supplies a directory for
persistent memory (for example a per-project memory folder, or a
`.agent/memory/` directory in the repo). Use whatever location the host
provides; if none exists and the user wants persistent memory, create a
clearly named directory and tell the user where it is.

Memory holds private, mutable, point-in-time knowledge (intent,
rationale, state, corrections). It is the counterpart to permanent
project history, which records only what exists — see the
`no-plans-on-main` rule. Keep plans and rationale in memory; keep the
commit/branch history about what shipped.

## 1. Decide what is worth saving

This is the hardest step and the one that keeps the store valuable.

Save:

- Who the user is and how they want you to work (role, expertise,
  standing preferences).
- The *why* behind a non-obvious decision, and decisions that are not
  derivable from the code or history.
- Durable architecture or product choices and their rationale.
- Active work state and goals that span sessions.
- Operational runbooks (how to reach an environment, run a tool, recover
  a state) when non-obvious.
- Corrections and confirmed approaches — how the user wants you to work
  differently, with the reason.

Do not save:

- What the repository, version-control history, or existing docs already
  record (code structure, past fixes, commit history, the project's own
  instruction files).
- What only matters to the current conversation.

If asked to remember something the project already records, ask what was
non-obvious about it and save that instead.

## 2. Write one fact per file with typed front matter

Each memory is a single file holding one fact, with front matter:

```markdown
---
name: <short-kebab-case-slug>
description: <one line — used to judge relevance during recall>
type: directive | decision | status | runbook | reference | feedback | user
load: always | recall | archive
status: active | superseded
updated: YYYY-MM-DD
triggers: [keyword, keyword]   # optional — words that should surface this
---
```

Field meanings:

- `name` — short kebab-case slug. Cross-references depend on exact slug
  matches, so keep them stable and do not prefix with the type.
- `description` — one line; what you scan during recall to decide whether
  to open the file.
- `type` — what kind of memory it is (semantic classification):
  - `directive` — a hard rule affecting many tasks.
  - `decision` — an architectural/product choice that remains true.
  - `status` — current state, versions, active work.
  - `runbook` — operational commands or host details.
  - `reference` — deep background needed only for certain work.
  - `feedback` — a user correction that should shape subsequent tasks.
  - `user` — who the user is and their standing preferences.
- `load` — the routing tier (see Organize, below): `always` (boot set),
  `recall` (load on demand when relevant), `archive` (out of the routine
  path).
- `status` — `active` or `superseded`. Superseded entries point to what
  replaced them and move to `archive`.
- `updated` — the date last revised, so staleness is visible.
- `triggers` — optional keywords that should surface this entry in recall.

Conventions:

- For `feedback` and `user` entries, follow the fact with **Why** and
  **How to apply** lines so the entry is actionable later.
- Convert relative dates ("last week", "yesterday") to absolute dates.
- Link related memories inline with `[[other-slug]]`. A link to a slug
  that does not exist yet is fine — it marks something worth writing
  later.

### Body shape: current truth first

For any substantial memory, lead with the load-bearing facts and push
history to the end, so a recalled or partial read gets the essentials
cheaply:

```markdown
## Current Truth
<what is true now — kept short; this is what a recalled read should get>

## Details
<background needed for task work in this area>

## Archive Notes
<completed or superseded history; safe to leave out of routine context>
```

Before saving, check for an existing file that already covers the fact
and update it rather than creating a duplicate. Delete memories that turn
out to be wrong; mark superseded ones `status: superseded`, point to what
replaced them, and re-tier them to `archive`.

## 3. Keep a lean router index

Maintain a single index file (for example `MEMORY.md`). It is **Tier 0**:
the one file loaded every session, so it is the always-paid cost floor —
keep it terse and let it grow only with real need.

- One line per active memory: a title or link plus a short hook, grouped
  by area, with enough signal to decide whether to open the file.
- Put archived memories in a collapsed section at the bottom that normal
  work does not route to.
- Add a one-line pointer when you create a memory; never put memory
  content in the index.

A starter index is in `templates/MEMORY.md`; a starter entry is in
`templates/memory-entry.md`.

## 4. Organize for scale (hierarchical load tiers)

A flat store works until it is large; then loading it costs too much
context. Organize it so routine sessions load little while the full corpus
stays available.

### Know where the cost is

Three separate costs, each with a different lever:

1. **The always-paid floor** — the router index (Tier 0). Lever: keep it
   terse; it grows linearly with the store.
2. **Recall cost** — the size of whatever entries get surfaced when
   relevant. Lever: keep recalled units small, so surfacing one fact does
   not drag a huge file with it.
3. **Full-read cost** — the entire corpus, paid only when something reads
   it all. Lever: move dead content out of the store.

### Split, do not summarize

The key principle. Do not compress large memories into lossy "summary
packs" — a summary that restates raw content is a second copy that drifts
the moment the source changes (it violates single source of truth).
Instead **split**: separate the small, slow-changing *current truth* from
the large, fast-accreting *history*. Current truth is naturally small, so
it can live in the boot set in its authoritative form with no duplication;
history moves to archive. You rarely need lossy summaries once
current-versus-historical is cleanly separated.

The biggest, churniest files (status/task-list/state memories) are the
prime targets: carve each into a small `load: always` current-state entry
plus a `load: archive` history entry.

### The load tiers

- **Tier 0 — Router** (`MEMORY.md`): always loaded; the index above.
- **Tier 1 — Boot set** (`load: always`): the hard rules
  (`type: directive`/`feedback`) plus one compact current-state entry.
  This is what belongs in context for nearly every session. Keep it small.
- **Tier 2 — Area memories** (`load: recall`): architecture, decision,
  runbook, reference, and package entries, surfaced on demand when the
  task matches. Each is current-truth-first so a recalled read is cheap.
- **Tier 3 — Archive** (`load: archive`): superseded plans and completed
  history. Kept for audit, but in files the router does not route to and
  the loader does not routinely index — so they stop costing context. An
  archive *section* inside an indexed file saves nothing; archive must be
  out of the routine path.

### When to escalate

Do not pre-build this for a small store. While the corpus is small, a flat
directory plus the router index is enough. Escalate to explicit tiers when
routine recall starts dragging large files, when the index grows past what
you want loaded every session, or when the largest one or two files
dominate the corpus. Use `scripts/agent-memory-report.sh` to see sizes and
which entries lack tiering.

### Verify the loader before using subdirectories

Some hosts' recall only indexes a flat directory and may not traverse
subfolders, and moving files can break the router's links. Confirm how the
host loads and recalls memory before reorganizing into subdirectories. If
unconfirmed, stay flat and tier with the `load` field plus naming, rather
than directory structure.

### Expect host frontmatter normalization

Some hosts rewrite an entry's front matter on save, keeping only `name`
and `description` at the top level and moving every other field (`type`,
`load`, `status`, `updated`, `triggers`, and any host-added bookkeeping
fields) under a `metadata:` map. Inline lists may also be rendered as
block lists.

This is expected and harmless: the tiering fields remain authoritative
wherever the host places them. Author entries in the flat form the
templates show; do not fight the rewrite. When auditing tiering by hand,
look under `metadata:` too. `agent-memory-report.sh` tolerates both
layouts.

## 5. Recall

At the start of a task, read the router index and pull the entries whose
descriptions or `triggers` match. Honor the tiers: load `always` entries
and the relevant current-state entry first, then `recall` entries the task
touches; do not pull `archive` entries unless you specifically need the
history.

Recalled memory is point-in-time. Before asserting a remembered file path,
version, flag, or command as current fact — or acting on it — verify it
against the present state (see the `agent-conduct` rule). If reality has
changed, trust the current state and update the memory (and its `updated`
date).
