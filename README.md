# agent-guidelines

Reusable project guidelines for AI coding agents.

This repository is a starting point for collecting rules, skills, and setup conventions that can be reused across agent-driven development tools.

## Local Tool Setup

Use `setup.sh` to link this repository's rules and skills into local
tool configuration directories:

```bash
./setup.sh --status
./setup.sh --dry-run
./setup.sh --install
```

Output uses aligned status labels and color when supported. Use
`--no-color` or set `NO_COLOR=1` for plain output.

Use `--backup-path <path>` with `--force` to choose where conflicting
files, directories, or foreign symlinks are moved before replacement.
Without an override, backups are written under
`$HOME/.agent-guidelines/backups/YYYYMMDD-HHMMSS/`.

### Managed Paths

`setup.sh` installs a curated **global** set: the rules marked
`load: always` in their YAML frontmatter and the skills listed in the
`GLOBAL_SKILLS` array near the top of `setup.sh`. Everything else stays
out of the global path and is opted in per project through
`project-setup.sh`.

`setup.sh` also assembles a global context file per harness containing
the same six rules inlined plus a router section that lists every
recall-tier rule with its trigger and a stable reference path. The
router's reference paths resolve through a single
`~/.agent-guidelines/rules` directory symlink that points at this
repository's `rules/`. The targets are `~/.claude/CLAUDE.md` for Claude
Code, `~/.config/opencode/AGENTS.md` for OpenCode,
`~/.pi/agent/AGENTS.md` for Pi, and `~/.codex/AGENTS.md` for Codex.
Only the marker-bracketed managed block is touched; any other content
you keep in those files stays intact.

The global set today:

| Kind | Managed path | Source |
| --- | --- | --- |
| Store | `$HOME/.agent-guidelines/rules` | `rules/` |
| Rule | `$HOME/.claude/rules/agent-conduct.md` | `rules/agent-conduct.md` |
| Rule | `$HOME/.claude/rules/development-attribution.md` | `rules/development-attribution.md` |
| Rule | `$HOME/.claude/rules/git-workflow.md` | `rules/git-workflow.md` |
| Rule | `$HOME/.claude/rules/git-messages.md` | `rules/git-messages.md` |
| Rule | `$HOME/.claude/rules/no-plans-on-main.md` | `rules/no-plans-on-main.md` |
| Rule | `$HOME/.claude/rules/merge-requests.md` | `rules/merge-requests.md` |
| Skill | `$HOME/.claude/skills/agent-memory` | `skills/agent-memory` |
| Skill | `$HOME/.claude/skills/code-review` | `skills/code-review` |
| Skill | `$HOME/.claude/skills/explain` | `skills/explain` |
| Skill | `$HOME/.claude/skills/project-setup` | `skills/project-setup` |
| Skill | `$HOME/.agents/skills/agent-memory` | `skills/agent-memory` |
| Skill | `$HOME/.agents/skills/code-review` | `skills/code-review` |
| Skill | `$HOME/.agents/skills/explain` | `skills/explain` |
| Skill | `$HOME/.agents/skills/project-setup` | `skills/project-setup` |
| Skill | `$HOME/.codex/skills/agent-memory` | `skills/agent-memory` |
| Skill | `$HOME/.codex/skills/code-review` | `skills/code-review` |
| Skill | `$HOME/.codex/skills/explain` | `skills/explain` |
| Skill | `$HOME/.codex/skills/project-setup` | `skills/project-setup` |
| Context | `$HOME/.claude/CLAUDE.md` | assembled from `rules/` |
| Context | `$HOME/.config/opencode/AGENTS.md` | assembled from `rules/` |
| Context | `$HOME/.pi/agent/AGENTS.md` | assembled from `rules/` |
| Context | `$HOME/.codex/AGENTS.md` | assembled from `rules/` |

Run the smoke tests for the local tool setup command with:

```bash
tests/setup-smoke.sh
```

## Rules

Rules live in `rules/` as Markdown files.

Rule files use wrapped Markdown prose and bullets, with continuation
lines indented under the text they continue. Keep examples, commands,
tables, and fenced blocks formatted for their own syntax.

- `git-workflow.md` defines branch, commit rhythm, merge readiness,
  publishing, and local file expectations.
- `git-messages.md` defines commit, merge, amendment, and temporary
  message file expectations.
- `agent-conduct.md` defines safe-conduct expectations: backing up before
  destructive actions, confirming irreversible work, treating sign-off
  assets as read-only, verifying point-in-time facts, and honest
  reporting.
- `no-plans-on-main.md` defines keeping roadmaps and forward-looking
  phrasing out of permanent history, with a banned-phrase pre-stage check.
- `docstrings.md` defines documentation comment expectations for code
  changes.
- `development-attribution.md` defines attribution boundaries for
  committed project files.
- `changelog-common.md` defines shared changelog format and initial
  setup expectations.
- `changelog-date.md` defines date-based changelog section and workflow expectations.
- `changelog-version.md` defines versioned changelog section and release
  cut expectations.
- `versioning-semver.md` defines semantic versioning and release expectations.
- `testing.md` defines verification expectations before merging branch work.
- `documentation.md` defines accuracy and example expectations for project docs.
- `configuration.md` defines repository, local, and secret configuration boundaries.
- `scripts.md` defines safety, UI, idempotency, error handling, and
  portability expectations for scripts.
- `code-quality.md` defines single-source-of-truth versions, not
  suppressing diagnostics, consistent terminology, realistic sample data,
  and aligned inline annotations.
- `engineering-judgment.md` defines explicit-over-auto choices, not
  designing against a single instance, single source of truth, and one
  writer per fact.
- `environment-hygiene.md` defines dependency install location,
  regenerating moved environments, and target-platform compatibility.
- `dependencies.md` defines expectations for adding, updating, and
  removing dependencies.
- `backward-compatibility.md` defines replacement, removal, migration,
  and release-impact expectations.

## Skills

Skills live in `skills/` as reusable agent workflows.

See `skills/README.md` for the current skill catalog.

## Project Setup Script

Use `project-setup.sh` to apply the `project-setup` workflow to a
target repository:

```bash
./project-setup.sh --profile codebase --changelog date /path/to/project
```

Per-project skills are opt-in via `--include-skill` (repeatable) and
land in `<project>/.agents/skills/<skill>/`, where OpenCode, Pi, and
Claude Code discover them. By default they use the same source mode as
rules (`--rules-source`); `--skills-source symlink|copy` lets you
override that independently. Symlink mode adds `.agents/skills/` to
the repository's local `.git/info/exclude` so the links stay out of
git; copy mode tracks the copied skill tree as a normal project asset.

Use `--dry-run` to preview every action without changing anything.
Most accurate against an existing git repository; on a fresh non-git
directory the preview reports the would-be repo init step and skips
git-dependent previews. The output flags whether the assembled
context block would be created, replace an existing managed block,
or append at the end because no marker pair was found.

```bash
./project-setup.sh --dry-run --profile codebase --changelog date .
```

```bash
./project-setup.sh --profile codebase \
  --include-skill test-audit \
  --include-skill firmware-review \
  /path/to/project
```

Run the smoke tests for the target-repository setup command with:

```bash
tests/project-setup-smoke.sh
```

## License

This repository is published under the
[PolyForm Noncommercial License 1.0.0](LICENSE.md). Noncommercial use
is freely permitted; commercial use requires a separate agreement
with the copyright holder.
