#!/usr/bin/env bash
# Verifies harness-specific project context and skill layouts.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-harness-tests.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

CLAUDE_REPO="$TMP_ROOT/claude"
CODEX_REPO="$TMP_ROOT/codex"
OPEN_CLAUDE_REPO="$TMP_ROOT/open-claude"
ALL_REPO="$TMP_ROOT/all"
COPY_REPO="$TMP_ROOT/copy"
INVALID_REPO="$TMP_ROOT/invalid"
MISSING_REPO="$TMP_ROOT/missing"
NONE_REPO="$TMP_ROOT/none"
LEGACY_REPO="$TMP_ROOT/legacy"
UNRELATED_REPO="$TMP_ROOT/unrelated-claude"
FOREIGN_CLAUDE="$TMP_ROOT/foreign-claude"
UNRELATED_AGENTS_REPO="$TMP_ROOT/unrelated-agents"
FOREIGN_AGENTS="$TMP_ROOT/foreign-agents"
IRRELEVANT_CLAUDE_REPO="$TMP_ROOT/irrelevant-claude-context"
IRRELEVANT_AGENTS_REPO="$TMP_ROOT/irrelevant-agents-context"

sha256_file() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{ print $1 }'
  else
    shasum -a 256 "$path" | awk '{ print $1 }'
  fi
}

"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none \
  --harness claude --include-skill explain \
  "$CLAUDE_REPO" >/dev/null

test -f "$CLAUDE_REPO/CLAUDE.md"
test ! -e "$CLAUDE_REPO/AGENTS.md"
test -L "$CLAUDE_REPO/.claude/skills/explain"
test ! -e "$CLAUDE_REPO/.agents/skills/explain"
grep -Fxq 'harness=claude' "$CLAUDE_REPO/.agent-guidelines/config"

"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none \
  --harness codex --include-skill explain \
  "$CODEX_REPO" >/dev/null

test ! -e "$CODEX_REPO/CLAUDE.md"
test -f "$CODEX_REPO/AGENTS.md"
test ! -e "$CODEX_REPO/.claude/skills/explain"
test -L "$CODEX_REPO/.agents/skills/explain"
grep -Fxq 'harness=codex' "$CODEX_REPO/.agent-guidelines/config"

# OpenCode can share Claude's tree when no .agents-only consumer is selected.
"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none \
  --harness claude --harness opencode --include-skill explain \
  "$OPEN_CLAUDE_REPO" >/dev/null

test -f "$OPEN_CLAUDE_REPO/CLAUDE.md"
test -f "$OPEN_CLAUDE_REPO/AGENTS.md"
test -L "$OPEN_CLAUDE_REPO/.claude/skills/explain"
test ! -e "$OPEN_CLAUDE_REPO/.agents/skills/explain"

"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none \
  --harness claude --harness codex --harness opencode --harness pi \
  --include-skill explain "$ALL_REPO" >/dev/null

test -L "$ALL_REPO/.claude/skills/explain"
test -L "$ALL_REPO/.agents/skills/explain"
test "$(readlink "$ALL_REPO/.claude/skills/explain")" = \
  "$(readlink "$ALL_REPO/.agents/skills/explain")"

# Replacing the harness set removes exact managed paths that no longer apply.
"$ROOT_DIR/project-setup.sh" --harness codex "$ALL_REPO" >/dev/null

test ! -e "$ALL_REPO/.claude/skills/explain"
test -L "$ALL_REPO/.agents/skills/explain"
if [ -e "$ALL_REPO/CLAUDE.md" ] &&
  grep -Fq '<!-- BEGIN agent-guidelines project rules -->' \
    "$ALL_REPO/CLAUDE.md"; then
  echo "deselected CLAUDE.md still contains the managed block" >&2
  exit 1
fi
grep -Fq '<!-- BEGIN agent-guidelines project rules -->' \
  "$ALL_REPO/AGENTS.md"
test "$(grep -c '^harness=' "$ALL_REPO/.agent-guidelines/config")" -eq 1
grep -Fxq 'harness=codex' "$ALL_REPO/.agent-guidelines/config"

# Claude copy mode remains a normal tracked project asset.
"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --skills-source copy \
  --harness claude --include-skill explain "$COPY_REPO" >/dev/null

test -d "$COPY_REPO/.claude/skills/explain"
test ! -L "$COPY_REPO/.claude/skills/explain"
git -C "$COPY_REPO" ls-files --error-unmatch \
  .claude/skills/explain/SKILL.md >/dev/null
if grep -Fxq '.claude/' "$COPY_REPO/.git/info/exclude"; then
  echo "tracked Claude skills are hidden by the local exclude" >&2
  exit 1
fi

if "$ROOT_DIR/project-setup.sh" \
  --harness codex --harness codex "$INVALID_REPO" \
  >"$TMP_ROOT/invalid.out" 2>"$TMP_ROOT/invalid.err"; then
  echo "duplicate harness selection unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'duplicate --harness value: codex' "$TMP_ROOT/invalid.err"
test ! -e "$INVALID_REPO"

if "$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --include-skill explain \
  "$MISSING_REPO" >"$TMP_ROOT/missing.out" 2>"$TMP_ROOT/missing.err"; then
  echo "missing harness selection unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'project skills require at least one --harness selection' \
  "$TMP_ROOT/missing.err"
test ! -e "$MISSING_REPO/.agent-guidelines"

# An explicit empty selection does not become a legacy shared layout.
"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none "$NONE_REPO" >/dev/null
grep -Fxq 'harness=none' "$NONE_REPO/.agent-guidelines/config"
if "$ROOT_DIR/project-setup.sh" --include-skill explain "$NONE_REPO" \
  >"$TMP_ROOT/none.out" 2>"$TMP_ROOT/none.err"; then
  echo "stored empty harness selection unexpectedly gained a skill" >&2
  exit 1
fi
grep -Fq 'project skills require at least one --harness selection' \
  "$TMP_ROOT/none.err"
grep -Fxq 'harness=none' "$NONE_REPO/.agent-guidelines/config"

# Configurations that predate harness selection migrate to every consumer.
"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --harness codex \
  --include-skill explain "$LEGACY_REPO" >/dev/null
sed -i '/^harness=/d' "$LEGACY_REPO/.agent-guidelines/config"
printf 'sha256=%s\n' \
  "$(sha256_file "$LEGACY_REPO/.agent-guidelines/config")" \
  >"$LEGACY_REPO/.git/agent-guidelines/ownership-v1/config"
"$ROOT_DIR/project-setup.sh" "$LEGACY_REPO" \
  >"$TMP_ROOT/legacy.out"
grep -Fq 'legacy project skill layout migrated to explicit harnesses' \
  "$TMP_ROOT/legacy.out"
for harness in claude codex opencode pi; do
  grep -Fxq "harness=$harness" \
    "$LEGACY_REPO/.agent-guidelines/config"
done
test -L "$LEGACY_REPO/.claude/skills/explain"
test -L "$LEGACY_REPO/.agents/skills/explain"

# A non-Claude selection does not inspect or traverse unrelated Claude state.
mkdir -p "$UNRELATED_REPO" "$FOREIGN_CLAUDE/skills"
ln -s "$FOREIGN_CLAUDE" "$UNRELATED_REPO/.claude"
"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --harness codex \
  "$UNRELATED_REPO" >/dev/null
"$ROOT_DIR/project-setup.sh" --remove "$UNRELATED_REPO" >/dev/null
test -L "$UNRELATED_REPO/.claude"
test "$(readlink "$UNRELATED_REPO/.claude")" = "$FOREIGN_CLAUDE"
test -d "$FOREIGN_CLAUDE/skills"

# A Claude-only selection applies the same boundary to shared harness state.
mkdir -p "$UNRELATED_AGENTS_REPO" "$FOREIGN_AGENTS/skills"
ln -s "$FOREIGN_AGENTS" "$UNRELATED_AGENTS_REPO/.agents"
"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --harness claude \
  "$UNRELATED_AGENTS_REPO" >/dev/null
"$ROOT_DIR/project-setup.sh" --remove "$UNRELATED_AGENTS_REPO" >/dev/null
test -L "$UNRELATED_AGENTS_REPO/.agents"
test "$(readlink "$UNRELATED_AGENTS_REPO/.agents")" = "$FOREIGN_AGENTS"
test -d "$FOREIGN_AGENTS/skills"

# Unselected context files do not participate in installation preflight.
mkdir -p "$IRRELEVANT_CLAUDE_REPO" "$IRRELEVANT_AGENTS_REPO"
printf '%s\n' '<!-- BEGIN agent-guidelines project rules -->' \
  >"$IRRELEVANT_CLAUDE_REPO/CLAUDE.md"
printf '%s\n' '<!-- BEGIN agent-guidelines project rules -->' \
  >"$IRRELEVANT_AGENTS_REPO/AGENTS.md"
"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --harness codex \
  "$IRRELEVANT_CLAUDE_REPO" >/dev/null
"$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --harness claude \
  "$IRRELEVANT_AGENTS_REPO" >/dev/null
test "$(wc -l <"$IRRELEVANT_CLAUDE_REPO/CLAUDE.md")" -eq 1
test "$(wc -l <"$IRRELEVANT_AGENTS_REPO/AGENTS.md")" -eq 1

printf 'project harness compatibility tests passed\n'
