---
when: always
load: always
summary: >-
  Conventional Commits format with a 50-character target on the
  subject and a 60-character hard cap enforced by the project-setup
  commit-msg hook. Spells out when a body is warranted, when
  subject-only is required (renames, file moves, typo fixes, comment
  corrections, narrowly scoped mechanical edits), the merge commit
  format, and the "history describes what is" discipline — commit
  bodies must not reference reverted work, iteration history, or
  another repository's needs.
---
# Git Message Rules

## Hard Constraints

- Write subjects as Conventional Commits `type(scope): description` —
  imperative, lowercase, no period, target 50 characters, hard cap 60.
- For renames, moves, typo fixes, and other mechanical edits, write
  the subject only — no body.
- For non-obvious changes, add a short body: WHAT and WHY, imperative,
  wrapped at 72 characters.
- Write multiline messages with a message file (`-F`), never repeated
  `-m` flags.
- Never reference reverted work, iteration history, another
  repository's needs, or before/after comparisons in bodies or
  changelog entries.
- When extending an existing feature, describe it at one consistent
  level of detail — enumerate all the peers or none.
- Amend only local, unpushed commits.
- Merge commits: subject `Merge branch '<branch-name>'`, one-paragraph
  body wrapped at 72, written with a message file.

Clear messages keep history readable from `git log`, hosting
platforms, release tooling, and revert workflows. The rationale and
detail behind each constraint:

## Commit Message Format

Follow the
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
standard:

```
<type>(<scope>): <description>
```

- **type** (required): `feat`, `fix`, `refactor`, `perf`, `docs`,
  `style`, `test`, `build`, `ci`, `chore`, `revert`
- **scope** (optional): a noun describing the affected section of the
  codebase, in parentheses
- **`!`** (optional): appended after type/scope to flag a breaking
  change
- **description**: a few characters over the 50-character target is
  acceptable when it improves clarity. The `commit-msg` hook installed
  by `project-setup.sh` enforces the 60-character cap on the total
  subject line. Merge commits — which use git's
  `Merge branch '<branch-name>'` subject — are exempt from both the
  format check and the length cap.
- **footer** (optional): `BREAKING CHANGE:`, `DEPRECATED:`,
  `Fixes #<issue>`, `Refs:`

## Commit Message Bodies

- For a mechanical edit, the diff is the explanation; if you find
  yourself writing a body for one, it is wrong-scoped — delete it
  before committing.
- Non-obvious intent, policy changes, workflow changes, cross-file
  edits, and user-visible behavior changes warrant a body — not a
  line-by-line restatement of the diff. When in doubt for these
  cases, two or three lines of useful rationale beat a subject that
  leaves future readers guessing.
- The message file keeps wrapped lines in their intended paragraphs.
  Use a unique filename per message, chain its removal onto the
  command that consumes it (`git commit -F msg.txt && rm -f msg.txt`),
  and sweep for leftovers at the end of the work. This applies to
  commit, merge, tag, and release messages alike.

## History Describes What Is

Commit bodies and changelog entries are permanent history. They
describe the state being committed, not the process that produced it.
Keep them self-contained and free of provenance.

- If an alternative was tried and discarded before committing, write
  the message as if it was never considered.
- Do NOT frame an issue as pre-existing. Describe the issue and the
  fix, not when or how the bug was introduced.
- Do NOT reference tag moves or rewrites. The result should read as
  intentional.
- A commit describes what changed in its own repository's terms;
  cross-repo justification belongs in the pull/merge request
  description, not in permanent history.
- State what the change does and why, not how it compares to what the
  old text said.

Before writing a body, check whether it references anything the
reader would not know about, and rewrite it to describe the present.
The matching discipline for forward-looking content is
`no-plans-on-main.md`.

## Consistent Level of Detail

When one option is added to a set or one field to a model after the
first implementation, singling out the new piece in the message,
description, or changelog reveals that the work was developed
iteratively in response to feedback. Describe the feature at one
level of abstraction instead.

## Amendments

- Amending unpushed commits is good when it improves branch quality:
  fixing a commit message, adding a missed file, removing accidental
  debug output, or keeping a small change with the commit it belongs
  to.
- Amending pushed or shared commits requires the team's explicit
  agreement to rewrite that history.
- Do not use amend to hide meaningful intermediate work that should
  remain as its own independently understandable commit.

## Merge Commit Messages

- The body summarizes the branch as one completed unit of work for
  humans reviewing project history — not a dump of every commit. Use
  multiple paragraphs only when the branch genuinely combines
  distinct units of work, and bullet lists only when the branch is
  unusually broad and a prose summary would hide important context.
- Example:

  ```text
  Merge branch 'feat/local-tool-setup'

  Merge the completed local tool setup command, managed tool links,
  backup handling, documentation, and smoke tests.
  ```
