# Docstring Rules

Every function, type, constant, macro, and module-scoped variable you
write or materially change MUST have an appropriate documentation
comment unless it is trivial and self-evident. Docstrings are part of
the code, not an afterthought — write them as you write the code, not as
a separate pass.

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
- All macros (constants and parameterized)
- All module-scoped and global variables
- All callbacks, handlers, ISRs, and lifecycle hooks
- File-level headers for non-trivial source files

## What to Skip

- Trivial getters/setters with no side effects
- Static helper functions that are a few lines long and self-evident
  from their name
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
