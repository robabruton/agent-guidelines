---
when: writing or modifying functions, types, modules, macros, or other documented code symbols
load: recall
summary: >-
  Documentation contracts for public symbols, non-trivial logic, and
  behavior-defining types, constants, macros, and state, with trivial
  exceptions. Specifies voice (third-person
  declarative), what to document, what to skip, and the idiomatic
  doc format per language — Doxygen, Google-style, JSDoc, Rustdoc,
  Godoc, Javadoc, LDoc.
---
# Docstring Rules

Every public symbol, non-trivial function, and behavior-defining type,
constant, macro, or module-scoped variable you write or materially
change MUST have an appropriate documentation comment. Docstrings are
part of the code; write them with the code.

## Voice and Style

- Use **third-person declarative**: "Initializes the DMA channel" — not
  "Initialize", not "This function initializes"
- The brief/short description must be one meaningful line that doesn't
  just repeat the name
  - BAD: "Handles data", "Does init", "Helper function"
  - GOOD: "Parses the incoming SPI frame and validates the checksum"
- Describe WHAT and WHY, not HOW — the code shows how
- Only add a longer description block if the function is genuinely
  complex or has non-obvious behavior
- Document return values including failure/edge cases
- Note important side effects, thread safety concerns, runtime
  assumptions, external resources, or hardware constraints

## What to Document

- All public/exported functions
- All functions with non-trivial logic
- All structs, enums, and typedefs, including per-field/per-value inline
  comments
- All classes, interfaces, records, traits, protocols, and other
  user-defined types
- Macros, constants, and module-scoped variables that affect behavior
  or configuration
- All callbacks, handlers, ISRs, and lifecycle hooks
- File-level headers for non-trivial source files

## What to Skip

- Trivial getters/setters with no side effects
- Trivial constructors, wrappers, and one-line helpers with no side
  effects or edge cases
- Private or static helpers that are short, local, and self-evident
- Do NOT add docstrings to code you didn't write or modify

## Language Formats

Use the idiomatic documentation standard for each language:

- **C / C++**: Doxygen (`/** @brief ... @param[in/out] ... @return
  ... @note ... */`). Use `@param[in]`, `@param[out]`,
  `@param[in,out]` directional annotations. Use `/**< ... */` for
  inline struct/enum member docs.
- **Python**: Google-style docstrings (`Args:`, `Returns:`, `Raises:`)
- **JavaScript / TypeScript**: JSDoc (`@param {type} name`,
  `@returns`, `@throws`)
- **Rust**: Rustdoc (`///` with `# Arguments`, `# Returns`, `# Errors` sections)
- **Go**: Godoc (comment block starting with the function/type name)
- **Java**: Javadoc (`@param`, `@return`, `@throws`)
- **Lua**: LDoc (`--- ... @param ... @return`)
- Other languages: use that language's most widely accepted doc comment
  standard
