---
when: always
load: always
---
# Git Message Rules

Use clear, structured Git messages so history remains readable from
`git log`, hosting platforms, release tooling, and revert workflows.

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
- **description**: imperative mood, lowercase, no period, target <=50
  characters; a few characters over is acceptable when it improves
  clarity. The `commit-msg` hook installed by `project-setup.sh`
  enforces a hard limit of 60 characters on the total subject line
  and rejects anything over that limit
- **body**: optional only for very small, self-evident changes. If a
  commit changes behavior, policy, workflow, touches multiple files, or
  would benefit from rationale, include a short body that explains WHAT
  changed and WHY. Imperative mood, wrap at 72 chars, and do not restate
  the diff line-by-line
- **footer** (optional): `BREAKING CHANGE:`, `DEPRECATED:`,
  `Fixes #<issue>`, `Refs:`

## Commit Message Bodies

- For a rename, a file move, a typo fix, a comment correction, or a
  narrowly scoped mechanical edit, write the subject only. The diff
  is the explanation; a body almost always over-explains these
  changes. If you find yourself writing one, the body is wrong-scoped
  and should be deleted before committing.
- Include a commit body for anything with non-obvious intent, policy
  changes, workflow changes, cross-file edits, or user-visible behavior
  changes
- When in doubt for the cases above, include a short body; two or
  three lines of useful rationale is better than a subject line that
  leaves future readers guessing
- Write multiline commit messages with `git commit -F <message-file>` so
  wrapped body lines stay in the intended paragraphs; do not use
  repeated `-m` flags for body paragraphs
- Delete temporary commit, merge, tag, or release message files
  immediately after the command that consumes them succeeds — chain the
  removal in the same step (e.g. `git commit -F msg.txt && rm -f
  msg.txt`). Use a unique filename per message so a later command does
  not pick up a stale one, and sweep for leftovers at the end of the work

## History Describes What Is

Commit bodies and changelog entries are permanent history. They describe
the state being committed, not the process that produced it. Keep them
self-contained and free of provenance.

- Do NOT reference absent or reverted work. If an alternative was tried
  and discarded before committing, write the message as if it was never
  considered.
- Do NOT frame an issue as pre-existing. Describe the issue and the fix,
  not when or how the bug was introduced.
- Do NOT reference tag moves or rewrites. The result should read as
  intentional.
- Do NOT reference other repositories' needs. A commit describes what
  changed in its own repository's terms; cross-repo justification belongs
  in the pull/merge request description, not in permanent history.
- Do NOT narrate before/after comparisons ("the docs said X but the code
  does Y"). State what the change does and why.

Before writing a body, check whether it references anything the reader
would not know about — iteration history, a reverted attempt, another
repository's behavior, what the old text said. If so, remove it and
describe the present.

## Consistent Level of Detail

When a feature is extended after its first implementation (one option
added to a set, one field added to a model), do not single out the new
piece in the commit message, merge message, description, or changelog.
Describe the feature at a consistent level of abstraction — enumerate all
the peers or none, never just the latest addition. Singling out the late
addition reveals that the work was developed iteratively in response to
feedback, which the permanent record should not carry.

## Amendments

- Amending local, unpushed commits is allowed when it improves branch
  quality, such as fixing a commit message, adding a missed file,
  removing accidental debug output, or keeping a small change with the
  commit it belongs to
- Do not amend commits that have already been pushed or shared unless
  the team explicitly agrees to rewrite that history
- Do not use amend to hide meaningful intermediate work that should
  remain as its own independently understandable commit

## Merge Commit Messages

- Merge commits use Git's explicit branch-grouping subject:
  `Merge branch '<branch-name>'`
- Use one body paragraph for normal merge commits. Summarize the branch
  as one completed unit of work; write it for humans reviewing project
  history, not as a dump of every commit on the branch.
- Use multiple body paragraphs only when the branch genuinely combines
  distinct units of work and separating them makes the merge easier to
  understand.
- Do not use bullet lists in merge commit bodies unless the branch is
  unusually broad and a prose summary would hide important context.
- Wrap body lines at 72 characters
- Write merge commit messages with `git commit -F <message-file>` so
  wrapped body lines stay in one paragraph; do not use repeated `-m`
  flags for continuation lines
- Example:

  ```text
  Merge branch 'feat/local-tool-setup'

  Merge the completed local tool setup command, managed tool links,
  backup handling, documentation, and smoke tests.
  ```
