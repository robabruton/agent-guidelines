---
when: always
load: always
---
# Pull / Merge Request Rules

A pull or merge request description is the permanent public record of a
branch. Write it for a reviewer reading it cold, and for anyone reading
project history months later. It should answer: what changed, why it was
needed, and how to verify it.

## Required Sections

Every description must have a **Summary**. Add the others when they apply.

### Summary

One to three sentences on what the branch does and why it was needed.
Align it with what the merge commit body will say — write both together.

- Focus on outcome and motivation, not implementation detail.
- If it fixes a bug, say what was wrong. If it adds a capability, say what
  it enables.
- Do not restate the branch name or the commit log.

### Changes

Use when the branch touches multiple distinct areas and prose would
obscure the separation. Omit for small, focused branches.

- One distinct area per bullet, one line each.
- Do not list every file changed.

### Test Evidence

State what was run and the outcome, specifically enough to reproduce.

- For automated tests: the command and whether it passed (e.g.
  `- <test command>: 136 passed`).
- For manual verification: what was checked and how.
- If a check could not be run, say why and describe the remaining risk.
- Do not claim "tested" without stating what was tested.
- Use bullet points, one check per bullet, so it scans in the platform UI.

### Notes

Anything a reviewer needs that is not obvious from the diff — decisions
made, deferrals, areas needing attention, known limitations. Omit if
nothing applies.

## Each Commit Must Stand on Its Own

Reviewers read the individual commits, not just the final diff. Every
commit in the branch must be correct as written.

- Do not leave `fix`/`fixup` commits that patch an earlier commit in the
  same branch. If a later change corrects an earlier commit, fold it in —
  rebuild the branch onto a clean base and amend the affected commit, or
  use an interactive autosquash where the project's hooks allow it.

## Never Reference Local-Only State

Reviewers cannot verify or act on your private checkout. Do not mention
untracked files, ignored content, temporary paths, or local-only
directories in the description, commit messages, or any shared artifact.

## Cross-Repository Context Belongs Here

Unlike commit bodies (which stay self-contained per the git-messages
rule), the request description is the right place for cross-repo
justification — why this branch exists in relation to other work. Put that
context here, not in the permanent commit/changelog history.

## Style

- Same imperative, plain-prose style as commit bodies.
- For a structured description with Summary/Changes/Test evidence/Notes
  sections, use `##` headings for each — do not mix headed and bare-line
  styles in one description. A genuinely simple one-paragraph description
  may omit headings entirely.
- Do not hard-wrap description prose; most platforms reflow markdown. Pick
  one convention (wrapped or unwrapped) and apply it consistently across
  the whole description — do not mix wrapped paragraphs with long bullet
  lines. (This differs from commit bodies, which do hard-wrap at 72.)
- Keep the title short and descriptive, like a commit subject: imperative,
  lowercase after the type prefix, no period.
- A short accurate description beats a long vague one; do not pad.
