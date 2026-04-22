---
name: docs-review
description: Review documentation for reader clarity, structure, tone, grammar, style, completeness, and task flow without turning it into a factual docs audit.
when_to_use: Use when reviewing README files, guides, rules, skill docs, setup instructions, or other documentation as writing for clarity, organization, tone, grammar, style, and reader success.
argument-hint: "[file|directory|project|changes]"
allowed-tools: Read Grep Glob
---

Review documentation as writing. Use this skill to assess whether docs
are clear, well-structured, grammatically sound, consistent in tone, easy
to scan, and complete enough for the intended reader to succeed.

This is not a factual docs audit. If the main question is whether
commands, options, paths, examples, or generated behavior match the
project, use `docs-audit` instead. In this skill, mention factual
questions only when they affect reader understanding and label them as
items to verify.

## Target Selection

Determine the review target from the user request:

- No target: review changed documentation.
- File path: review that documentation file.
- Directory path: review documentation under that directory.
- `project`: review primary project documentation.

For changed-doc reviews, inspect both staged and unstaged changes. Use
`git diff --name-only`, `git diff --cached --name-only`, and
`git status --short` when available.

Prefer `rg --files` to find documentation. Likely targets include README
files, guides, rule files, skill files, changelog guidance, docs
directories, and setup instructions.

## Review Areas

### Reader and Purpose

- The intended reader is unclear or shifts unexpectedly.
- The document does not state enough context for the reader to know when
  or why to use it.
- The level of detail does not match the reader's likely experience.
- The document assumes knowledge that should be introduced.

### Structure and Flow

- Sections are ordered in a way that makes the task harder to complete.
- Headings are too broad, too vague, or inconsistent with their content.
- Related information is split apart without a reason.
- Dense lists or paragraphs should be split, grouped, or reordered for
  scanability.
- Important warnings, prerequisites, or next steps appear too late.

### Clarity and Ambiguity

- Sentences can be read in more than one plausible way.
- Instructions lack an actor, object, condition, or expected outcome.
- Pronouns, references, or terms are unclear.
- Similar concepts use inconsistent names.
- The document mixes policy, explanation, and procedure without clear
  transitions.

### Completeness for Reader Success

- A task lacks prerequisite context, expected result, or next step.
- A concept is introduced but not defined enough to be useful.
- A decision point lacks criteria.
- A warning says what not to do but not what to do instead.
- A troubleshooting or verification step is missing where a reader would
  naturally need one.

### Tone and Style

- Tone is inconsistent with the project voice or audience.
- Wording is too casual, too formal, too vague, or unnecessarily harsh.
- Sentences are wordy, repetitive, or padded.
- The document uses marketing language where operational clarity would be
  better.
- The document over-explains obvious details or under-explains important
  tradeoffs.

### Grammar and Mechanics

- Grammar, punctuation, or spelling issues that reduce professionalism or
  clarity.
- Inconsistent capitalization, heading style, terminology, or list
  structure.
- Awkward sentence construction that slows comprehension.
- Formatting choices that make examples, paths, commands, or terms hard
  to scan.

## Review Process

1. Identify the document's likely reader and task.
2. Read the whole relevant document before forming findings.
3. Review for reader success first, then structure, clarity, tone,
   grammar, and mechanics.
4. For changed docs, inspect surrounding sections so findings account for
   context.
5. Separate must-fix issues from optional improvements.

Do not rewrite the entire document unless the user explicitly asks for a
rewrite. Prefer targeted findings and suggested edits.

Short replacement text is helpful when a sentence or heading is the
problem. Keep suggested wording concise and limited to the affected
passage.

Do not report personal taste as a finding. Tie each issue to reader
confusion, task failure, inconsistency, maintainability, or project voice.

Do not duplicate `docs-audit`. If a concern requires checking code,
scripts, generated output, or actual command behavior, mark it as
something to verify rather than presenting it as confirmed.

## Finding Standard

Each finding must include:

- The documentation location.
- The reader-facing problem.
- Why it matters.
- A concrete edit or direction.

Suppress a concern when it is purely subjective, does not affect reader
understanding, or would only make the document match one person's style
preference.

If suggesting replacement wording, separate it from the finding so the
reader can distinguish diagnosis from proposed text.

## Output Format

Lead with findings grouped by priority:

```text
Must Fix
- path:line - Issue. Why it matters. Suggested edit.

Should Improve
- path:line - Issue. Why it matters. Suggested edit.

Optional
- path:line - Issue. Why it matters. Suggested edit.

Verify
- path:line - Factual question that needs docs-audit or source checking.
```

Use these priorities:

- **Must Fix:** The issue can mislead readers, block task completion, or
  materially damage professionalism.
- **Should Improve:** The issue creates avoidable confusion, weak flow, or
  inconsistent reader experience.
- **Optional:** The issue is a low-risk polish or maintainability
  improvement.
- **Verify:** The issue may be factual, but needs source checking before
  being treated as confirmed.

After findings, include:

- Documentation surfaces reviewed.
- Main reader/task assumption.
- Any areas intentionally not reviewed.

If no issues are found, say that clearly and state what was reviewed.
