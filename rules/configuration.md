# Configuration Rules

Configuration should make the project reproducible without committing
private machine state, secrets, or personal tool preferences.

## Repository Configuration

- Commit configuration that is required to build, test, run, package, or
  operate the project
- Commit example configuration when users need a template, using safe
  placeholder values
- Keep example files clearly named, such as `.env.example`,
  `config.example.toml`, or similar project conventions
- Document required environment variables, config files, defaults, and
  where real values should come from

## Local Configuration

- Keep personal editor, agent, credential, token, cache, and
  machine-specific files out of git
- Use local excludes or documented ignore patterns for files that are
  private to one developer
- Prefer relative paths, documented environment variables, or
  project-root-based paths over user- or machine-specific absolute paths
- Do not commit user- or machine-specific absolute paths unless they are
  required examples and clearly marked as placeholders
- Do not add broad ignore patterns that hide legitimate project files
- If a local-only file is needed for setup, provide a committed example
  or documented instructions instead of committing the real file

## Secrets

- Never commit secrets, credentials, access tokens, private keys, session
  data, or production values
- Do not include realistic secret values in examples, tests, docs, or comments
- If a secret is accidentally committed, treat it as compromised and rotate it
- Prefer references to secret storage, environment variables, or
  deployment configuration over hardcoded values
