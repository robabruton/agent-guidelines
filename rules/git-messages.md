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
  clarity, but do not treat 72 characters as the normal subject length
- **body**: optional only for very small, self-evident changes. If a
  commit changes behavior, policy, workflow, touches multiple files, or
  would benefit from rationale, include a short body that explains WHAT
  changed and WHY. Imperative mood, wrap at 72 chars, and do not restate
  the diff line-by-line
- **footer** (optional): `BREAKING CHANGE:`, `DEPRECATED:`,
  `Fixes #<issue>`, `Refs:`

## Commit Message Bodies

- A one-line summary-only commit message is acceptable for simple
  changes that are obvious from the diff, such as a typo fix, a comment
  correction, or a narrowly scoped mechanical edit
- Include a commit body for anything with non-obvious intent, policy
  changes, workflow changes, cross-file edits, or user-visible behavior
  changes
- When in doubt, include a short body; two or three lines of useful
  rationale is better than a subject line that leaves future readers
  guessing
- Write multiline commit messages with `git commit -F <message-file>` so
  wrapped body lines stay in the intended paragraphs; do not use
  repeated `-m` flags for body paragraphs
- Delete temporary files, including commit, merge, tag, or release
  message files, once they are no longer needed

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
