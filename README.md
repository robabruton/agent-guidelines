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

`--status` verifies each assembled context file against the current
rules and reports it as current, stale, or missing; `--dry-run`
previews only the files an install would actually change. Run
`--install` to refresh anything reported stale.

Use `--backup-path <path>` with `--force` to choose the parent directory
for conflict backups. Before replacing anything, setup copies every full
conflicting file, directory, or foreign symlink into one unique
`run.XXXXXX` recovery directory and verifies its type, content, and
metadata. Without an override, recovery directories are created under
`$HOME/.agent-guidelines/backups/`. The exact path is printed in the
result summary.

### Managed Paths

`setup.sh` installs every catalogued skill globally: the skills listed in
the `GLOBAL_SKILLS` array near the top of `setup.sh`, a stable rules store
symlink, and one assembled context file per harness. Skill instructions
load when their trigger matches a task rather than loading for every
conversation.

Each assembled context file contains the rules marked `load: always`
in their YAML frontmatter inlined, plus a router section that lists
every recall-tier rule with its trigger and a stable reference path.
The router's reference paths resolve through a single
`~/.agent-guidelines/rules` directory symlink that points at this
repository's `rules/`. The targets are `~/.claude/CLAUDE.md` for Claude
Code, `~/.config/opencode/AGENTS.md` for OpenCode,
`~/.pi/agent/AGENTS.md` for Pi, and `~/.codex/AGENTS.md` for Codex.
Only the marker-bracketed managed block is touched; any other content
you keep in those files stays intact.

The context files are the only global delivery channel for rules, so a
harness that also reads a per-rule directory never loads the same rule
twice. `setup.sh --prune` reports repository-pointing per-rule symlinks
in `~/.claude/rules/` as ambiguous ownership candidates and leaves them
unchanged for inspection.

The `GLOBAL_SKILLS` array is the authoritative global set and currently
contains every entry in `skills/`. These managed-path patterns apply to
each skill:

| Kind | Managed path | Source |
| --- | --- | --- |
| Store | `$HOME/.agent-guidelines/rules` | `rules/` |
| Skill | `$HOME/.claude/skills/<skill>` | `skills/<skill>` |
| Skill | `$HOME/.agents/skills/<skill>` | `skills/<skill>` |
| Skill | `$HOME/.codex/skills/<skill>` | `skills/<skill>` |
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

See `rules/README.md` for the current rule catalog.

## Skills

Skills live in `skills/` as reusable agent workflows.

See `skills/README.md` for the current skill catalog.

## Project Setup Script

Use `project-setup.sh` to apply the `project-setup` workflow to a
target repository:

```bash
./project-setup.sh --profile codebase --changelog date /path/to/project
```

Global installation is sufficient for normal local use. Per-project
skills remain opt-in via `--include-skill` (repeatable) when a repository
needs a portable copy or pinned snapshot. Every invocation that selects
project-local skills also names at least one consumer with repeatable
`--harness claude|codex|opencode|pi` options. Setup installs only the
skill trees those consumers need:

| Selected consumers | Project skill tree |
| --- | --- |
| Claude Code | `.claude/skills/` |
| Codex or Pi | `.agents/skills/` |
| OpenCode alone or with Codex/Pi | `.agents/skills/` |
| Claude Code and OpenCode, without Codex/Pi | `.claude/skills/` |

Selections that need both trees receive canonical-identical links or
copies. `--exclude-skill` cancels a matching project-local selection in
the same invocation; it does not hide a globally installed skill.

By default, project-local skills use the same source mode as rules
(`--rules-source`); `--skills-source symlink|copy` overrides that
independently. Symlink mode locally excludes the selected skill trees so
the links stay out of git; copy mode tracks them as normal project assets.
Every copied rule or skill root contains `POLYFORM-NONCOMMERCIAL.txt` with
the PolyForm Noncommercial 1.0.0 terms URL. Setup displays the same notice
before copy-mode writes to the target repository. When an existing snapshot
otherwise matches its canonical source exactly, setup adds a missing notice;
every other mismatch stops the operation before mutation.

Named harness selections also limit project context files: Claude Code
uses `CLAUDE.md`, while Codex, OpenCode, and Pi use `AGENTS.md`. With no
named harness and no project-local skills, setup emits both files for
compatibility. Each file contains a self-contained compact policy with
the hard constraints from every selected always-loaded rule and a complete
router for situational rules. Setup rejects a generated managed policy above
12,288 bytes or a complete candidate file above 24,576 bytes before mutation.
The complete-file limit includes preserved project-specific content. `compact`
is the canonical `--context-rules` mode; the compatibility values `auto`,
`full`, and `trimmed` migrate to it.

Reruns load the selected profile, changelog and context modes, source
modes, harnesses, default branch, and rule and skill selections from the
checksum-owned `.agent-guidelines/config` file. The file uses a versioned,
non-executable data format. Omitted options preserve the stored selection;
explicit options update only the named settings. Malformed, changed, or
unowned setup state stops the operation before mutation.

Project setup accepts only exact canonical symlinks and exact managed
copies at rule and skill destinations. Foreign paths, malformed managed
blocks, and user-managed local Git configuration stop the operation
before mutation. Local state created by setup is recorded under the
repository's Git directory in `agent-guidelines/ownership-v1`; removal
uses those records and the current exact value, leaving matching legacy
state without a record in place.

An existing Git target must be its worktree root, and setup does not create
a missing target beneath another worktree. Repository redirects and hook
paths outside the target's own Git metadata are rejected. Git identity is
resolved in the target repository's configuration context.

Setup preserves the repository's detected default branch and configures
both branch-policy hooks from the same stored value. It never renames or
checks out a branch. Use `--default-branch <name>` when automatic detection
is ambiguous; a new repository uses `main` unless that option selects
another valid name. A new repository's Git metadata is assembled beside
the target and installed only after setup succeeds. Only a repository
created by that invocation receives the managed initial commit; existing
unborn repositories remain uncommitted, and staged unborn content is
rejected unchanged. That initial commit contains only artifacts created by
the setup invocation, leaving pre-existing target files untracked. Failed
final installation or verification retains and reports complete Git recovery
state.

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
  --harness codex \
  --include-skill test-audit \
  --include-skill firmware-review \
  /path/to/project
```

Run the target-repository and hook safety suites with:

```bash
for test in tests/project-*.sh tests/hooks-smoke.sh; do
  "$test"
done
```

## License

This repository is published under the
[PolyForm Noncommercial License 1.0.0](LICENSE.md). Noncommercial use
is freely permitted; commercial use requires a separate agreement
with the copyright holder.
