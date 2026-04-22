---
name: docstrings
description: Add or update language-appropriate documentation comments for public symbols and non-trivial code while preserving accurate existing docs.
when_to_use: Use when adding or updating docstrings for files, directories, changed code, public APIs, structs, enums, callbacks, macros, or non-trivial source symbols.
argument-hint: "[file|directory|symbol|project|changes]"
---

Add or update documentation comments for source symbols. Use this skill
when code needs idiomatic docstrings, stale comments need correction, or
changed code should be brought up to the project's documentation
standard.

This is an editing workflow, not a style-only review. Preserve accurate
existing docstrings, avoid documenting obvious code, and make each added
comment reflect the code as it exists.

## Target Selection

Determine the target from the user request:

- No target: document changed source files.
- File path: document relevant symbols in that file.
- Directory path: document relevant source files under that directory.
- Symbol name: find and document that symbol.
- `project`: document relevant source files across the project.
- `changes`: document staged and unstaged source changes.

For changed-code targets, inspect both staged and unstaged changes. Use
`git diff --name-only`, `git diff --cached --name-only`, and
`git status --short` when available.

Prefer `rg --files` to find source files. Prioritize files in
languages with established documentation conventions, public API
surfaces, headers, interfaces, exported modules, callbacks, ISRs,
structs, enums, macros, and non-trivial implementation code.

When the request names a symbol, search for the definition before
editing. If multiple definitions match, document the one in the
requested scope or ask for clarification only when the target is
genuinely ambiguous.

## What To Document

Document symbols where a reader benefits from an explicit contract:

- Public or exported functions, methods, classes, interfaces, traits,
  protocols, and modules.
- Structs, enums, typedefs, data classes, and public fields or variants.
- Macros, constants, and module-scoped variables that affect behavior or
  configuration.
- Callbacks, ISRs, handlers, lifecycle hooks, entry points, and API
  boundary functions.
- Private or static functions with non-trivial logic, side effects,
  failure modes, concurrency concerns, hardware assumptions, parsing, or
  resource ownership.
- Changed symbols whose old documentation is missing, stale, incomplete,
  or misleading.

Skip symbols that do not need a docstring:

- Trivial getters, setters, constructors, wrappers, and one-line helpers
  with no side effects or edge cases.
- Private helpers that are short, local, and self-evident from their
  name and body.
- Generated, vendored, minified, or third-party code unless the user
  explicitly asks to edit it.
- Code outside the requested scope.
- Accurate existing docstrings that already describe behavior, inputs,
  outputs, errors, and important side effects.

Do not add docstrings to code you did not inspect. Read the symbol body,
nearby types, and representative callers when needed before writing or
changing the comment.

## Language Formats

Use the idiomatic documentation convention for each language:

- **C / C++:** Doxygen comments. Use `@brief`, directional
  `@param[in]`, `@param[out]`, or `@param[in,out]`, `@return`, and
  `@note` where useful. Use inline member comments such as `/**< ... */`
  for struct fields and enum values when that matches local style.
- **Python:** Google-style docstrings with `Args:`, `Returns:`,
  `Raises:`, and `Yields:` sections as applicable.
- **JavaScript / TypeScript:** JSDoc with `@param`, `@returns`, and
  `@throws`. Include type annotations in JSDoc only when they add value
  or match local style.
- **Rust:** Rustdoc with `///`, plus `# Arguments`, `# Returns`, and
  `# Errors` sections when the function contract needs them.
- **Go:** Godoc comments that start with the exported identifier's name.
- **Java / Kotlin:** Javadoc or KDoc with `@param`, `@return`, and
  `@throws` or `@exception`.
- **C#:** XML documentation comments with `<summary>`, `<param>`,
  `<returns>`, and `<exception>` elements.
- **Ruby:** YARD comments with `@param`, `@return`, and `@raise`.
- **Lua:** LDoc comments with `---`, `@param`, `@return`, and `@raise`
  where applicable.
- **PHP:** PHPDoc comments with `@param`, `@return`, and `@throws`.
- **Shell:** Comments above non-trivial functions that describe purpose,
  inputs, outputs, side effects, and expected global variables when the
  project uses shell functions as APIs.

For other languages, use the most common documentation comment standard
for that language and match the surrounding project style.

## Writing Standard

Write docstrings as source contracts, not prose decoration:

- Use third-person declarative voice: "Parses the incoming SPI frame and
  validates the checksum."
- Make the first line meaningful and specific. Do not repeat the symbol
  name in different words.
- Describe what the symbol does and why callers care; let the code show
  how it does it.
- Document parameters by purpose and valid expectations, not just type.
- Document return values, including false, nil, error, empty, or partial
  results.
- Document raised exceptions, returned errors, panic conditions, or
  status codes when visible from the code.
- Note side effects such as file writes, network calls, hardware access,
  global state changes, ownership transfer, locking, allocation, or
  cleanup responsibility.
- Note thread-safety, interrupt context, lifetime, ordering, platform,
  or hardware assumptions when they affect callers.
- Keep comments concise. Add longer descriptions only for complex or
  non-obvious behavior.

Do not speculate. If behavior is unclear after inspection, leave a
narrow note in the final summary rather than inventing a contract.

## Contract Details

Include contract details only when the code exposes them:

- Valid ranges, accepted units, ownership rules, lifetime requirements,
  nullability, mutability, and default behavior.
- Failure behavior, including retries, partial writes, cleanup,
  cancellation, timeout, and fallback behavior.
- Concurrency expectations such as locking, reentrancy, async context,
  signal safety, ISR safety, and thread affinity.
- Persistence or external effects such as filesystem writes, database
  updates, network calls, hardware registers, logs, metrics, and emitted
  events.

Avoid implementation trivia, restating obvious type information, or
describing every branch in the function body.

## Edit Process

1. Identify source files and symbols in scope.
2. Inspect each symbol's body and any existing documentation.
3. Preserve accurate docstrings unchanged.
4. Update stale or incomplete docstrings in place.
5. Add missing docstrings only for symbols that meet the documentation
   threshold.
6. Match local formatting, line wrapping, indentation, and comment
   style.
7. Re-run focused formatting or tests when the project provides them and
   the edit risk warrants it.

Keep edits scoped to documentation comments unless the user explicitly
asks for code changes. Do not rename symbols, change behavior, reformat
unrelated code, or convert comment styles project-wide as part of this
skill.

When a file has many undocumented symbols, work in coherent groups and
avoid leaving more than a small set of unrelated files modified at once.

## Output Format

After editing, summarize the work by file:

```text
Updated
- path: added N docstrings, updated N existing docstrings

Skipped
- path:symbol - Reason.

Verification
- Command or check run, or why none was run.

Notes
- Any ambiguous contracts or follow-up documentation gaps.
```

For review-only use, lead with missing, stale, or misleading docstring
findings instead of an edit summary:

```text
High
- path:line - Missing or incorrect contract. Suggested fix.

Medium
- path:line - Incomplete parameter, return, error, or side-effect docs.

Low
- path:line - Minor clarity or convention issue.
```

If no changes are needed, say that clearly and state what was inspected.
