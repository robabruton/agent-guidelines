---
name: explain
description: Explain code, files, workflows, commands, or project concepts clearly without editing files or producing review findings. Use for understanding; use code-review for inspection findings and debug for a concrete failure that needs a fix.
when_to_use: Use when the user asks to understand a file, function, command, workflow, architecture, data flow, branch, error path, or project concept.
argument-hint: "[file|directory|symbol|command|workflow|project|changes]"
allowed-tools: Read Grep Glob
---

Explain how something works. Use this skill when the user wants
understanding, orientation, onboarding, or a trace through code or
workflow behavior without changing files.

This is not a review, audit, or rewrite skill. Mention risks or
improvements only when they are necessary to explain behavior, and label
them as observations rather than findings.

## Target Selection

Determine the target from the user request:

- File path: explain that file's purpose, structure, and important
  behavior.
- Directory path: explain the relevant components and how they relate.
- Symbol name: find and explain that function, type, command, or
  variable.
- Command: explain what it does, inputs, outputs, side effects, and
  common failure points.
- Error path or log message: explain the likely code path and what
  context would confirm it.
- Workflow: explain the sequence, decision points, files touched, and
  expected result.
- Branch or changes: explain the changed behavior and why the changes
  matter.
- `project`: explain the project structure and primary workflows.

For changed-code explanations, inspect both staged and unstaged changes.
Use `git diff --name-only`, `git diff --cached --name-only`, and
`git status --short` when available.

Prefer `rg --files` to find relevant source, tests, scripts,
configuration, docs, and generated templates. Read enough surrounding
context to avoid explaining a function or file in isolation when callers
or generated behavior matter.

## Explanation Focus

### Purpose

- What the target is for.
- Who or what calls it.
- What problem it solves in the project.
- Where it fits in the larger workflow.

### Structure and Flow

- The main sections, functions, types, or steps.
- Input, transformation, output, and side effects.
- Important branches, guard conditions, and failure paths.
- Data flow across files or commands when relevant.

### Contracts and Dependencies

- Public interfaces, flags, arguments, config keys, files, environment
  variables, generated outputs, or external commands.
- Assumptions about current working directory, filesystem state, user
  input, platform, network, hardware, or tool availability.
- Ownership, lifecycle, cleanup, persistence, or compatibility behavior
  that callers depend on.

### Gotchas and Boundaries

- Non-obvious behavior that could surprise a maintainer.
- Things that are intentionally out of scope.
- Similar concepts that are easy to confuse.
- Places where a deeper audit or review would be needed to make a
  quality judgment.

## Audience and Depth

Infer the audience from the request:

- Newcomer or onboarding: explain terms, file roles, and the main path
  before edge cases.
- Maintainer: emphasize contracts, side effects, invariants, and where
  changes usually belong.
- Debugging context: explain the relevant path and state assumptions.
  Do not turn the response into a full debugging session unless asked.
- Review context: explain what changed and why it matters without
  assigning severity or making review findings.

If the requested scope is too broad, give a useful map first and
identify the highest-value areas for deeper follow-up.

## Style

- Start with the plain-language purpose before details.
- Match depth to the user's question. Do not dump every line or function
  when a concise explanation is enough.
- Use file and line references for important claims when possible.
- Prefer concrete examples from the code over abstract descriptions.
- Define project-specific terms before using them heavily.
- Avoid speculation. If behavior is unclear, say what is known and what
  would need more inspection.
- Do not present subjective style preferences as facts.

Use diagrams only when they clarify real complexity. Keep diagrams small
and text-based unless the user asks for another format.

## Output Shapes

Choose the shape that fits the request:

```text
Short Explanation
- Purpose
- How it works
- Important details
```

```text
Walkthrough
1. Entry point
2. Main flow
3. Side effects
4. Failure or edge cases
5. Result
```

```text
Project or Directory Map
- Component - Purpose and relationships.
```

```text
Change Explanation
- What changed
- Why it matters
- Behavior before and after
- Tests or docs that relate
```

```text
Error Path Explanation
- Where the error likely starts
- Relevant state or input
- How the code reaches the outcome
- What would confirm the explanation
```

End with:

- Files or surfaces inspected.
- Any assumptions or areas not inspected.
- Optional next checks only when they naturally follow from the user's
  goal.
