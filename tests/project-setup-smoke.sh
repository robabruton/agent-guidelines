#!/usr/bin/env bash
# Verifies the target repository setup command in temporary repositories.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-tests.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

SYMLINK_REPO="${TMP_ROOT}/symlink-repo"
COPY_REPO="${TMP_ROOT}/copy-repo"
TRIMMED_REPO="${TMP_ROOT}/trimmed-repo"
DRY_REPO="${TMP_ROOT}/dry-repo"
SYMLINK_FIRST_OUT="${TMP_ROOT}/symlink-first.out"
SYMLINK_SECOND_OUT="${TMP_ROOT}/symlink-second.out"
SYMLINK_STATUS_OUT="${TMP_ROOT}/symlink-status.out"
COPY_OUT="${TMP_ROOT}/copy.out"
COPY_STATUS_OUT="${TMP_ROOT}/copy-status.out"
TRIMMED_OUT="${TMP_ROOT}/trimmed.out"
TRIMMED_STATUS_OUT="${TMP_ROOT}/trimmed-status.out"
DRY_OUT="${TMP_ROOT}/dry.out"

assert_agent_rules() {
  local file="$1"
  local expected_heading="$2"

  test -f "$file"
  grep -Fq "<!-- BEGIN agent-guidelines project rules -->" "$file"
  grep -Eq "^## Git Workflow Rules$" "$file"
  grep -Fq "$expected_heading" "$file"
  grep -Fq "<!-- END agent-guidelines project rules -->" "$file"
  if grep -Eq "^# " "$file"; then
    echo "stray H1 in $file" >&2
    return 1
  fi
  if awk 'BEGIN{p=""} /^$/&&p==""{f=1;exit} {p=$0} END{exit !f}' "$file"; then
    echo "consecutive blank lines in $file" >&2
    return 1
  fi
}

assert_agent_preamble() {
  local file="$1"

  test -f "$file"
  grep -Fq "**Generated file.**" "$file"
  grep -Fq "## Project-Specific Notes" "$file"
  # Preamble lives ABOVE the marker block
  marker_line="$(grep -nF '<!-- BEGIN agent-guidelines project rules -->' "$file" | head -1 | cut -d: -f1)"
  preamble_line="$(grep -nF '## Project-Specific Notes' "$file" | head -1 | cut -d: -f1)"
  test "$preamble_line" -lt "$marker_line"
}

"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog dated \
  --context-rules full \
  --include-skill explain \
  --include-skill test-audit \
  --exclude-skill test-audit \
  "${SYMLINK_REPO}" > "$SYMLINK_FIRST_OUT"

git -C "$SYMLINK_REPO" status --short > "$SYMLINK_STATUS_OUT"
if [ -s "$SYMLINK_STATUS_OUT" ]; then
  cat "$SYMLINK_STATUS_OUT" >&2
  echo "symlink mode left uncommitted project changes" >&2
  exit 1
fi

test -L "${SYMLINK_REPO}/.agent-guidelines/rules"
test -f "${SYMLINK_REPO}/.git/hooks/pre-commit"
grep -Fq "Changelog mode: date" "$SYMLINK_FIRST_OUT"
assert_agent_rules "${SYMLINK_REPO}/CLAUDE.md" "# Date-Based Changelog Rules"
assert_agent_rules "${SYMLINK_REPO}/AGENTS.md" "# Date-Based Changelog Rules"
assert_agent_preamble "${SYMLINK_REPO}/CLAUDE.md"
assert_agent_preamble "${SYMLINK_REPO}/AGENTS.md"

test -L "${SYMLINK_REPO}/.agents/skills/explain"
test ! -e "${SYMLINK_REPO}/.agents/skills/test-audit"
grep -Fq ".agents/skills/" "${SYMLINK_REPO}/.git/info/exclude"

"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog dates \
  --context-rules full \
  "${SYMLINK_REPO}" > "$SYMLINK_SECOND_OUT"

git -C "$SYMLINK_REPO" status --short > "$SYMLINK_STATUS_OUT"
if [ -s "$SYMLINK_STATUS_OUT" ]; then
  cat "$SYMLINK_STATUS_OUT" >&2
  echo "second symlink run was not idempotent" >&2
  exit 1
fi

grep -Fq "Created:" "$SYMLINK_SECOND_OUT"
grep -Fq "  none" "$SYMLINK_SECOND_OUT"
# Preamble must survive idempotent re-run
assert_agent_preamble "${SYMLINK_REPO}/CLAUDE.md"
assert_agent_preamble "${SYMLINK_REPO}/AGENTS.md"

"${ROOT_DIR}/project-setup.sh" \
  --profile released \
  --changelog versions \
  --context-rules full \
  --rules-source copy \
  --include-skill firmware-review \
  "${COPY_REPO}" > "$COPY_OUT"

git -C "$COPY_REPO" status --short > "$COPY_STATUS_OUT"
if [ -s "$COPY_STATUS_OUT" ]; then
  cat "$COPY_STATUS_OUT" >&2
  echo "copy mode left uncommitted project changes" >&2
  exit 1
fi

test -f "${COPY_REPO}/.agent-guidelines/rules/versioning-semver.md"
git -C "$COPY_REPO" ls-files --error-unmatch \
  .agent-guidelines/rules/versioning-semver.md >/dev/null
grep -Fq "Versioning mode: semver" "$COPY_OUT"
assert_agent_rules "${COPY_REPO}/CLAUDE.md" "# Semantic Versioning Rules"
assert_agent_rules "${COPY_REPO}/AGENTS.md" "# Semantic Versioning Rules"

test -d "${COPY_REPO}/.agents/skills/firmware-review"
test ! -L "${COPY_REPO}/.agents/skills/firmware-review"
test -f "${COPY_REPO}/.agents/skills/firmware-review/SKILL.md"
git -C "$COPY_REPO" ls-files --error-unmatch \
  .agents/skills/firmware-review/SKILL.md >/dev/null

# Trimmed context mode: the managed block is a rule selection router
# instead of inlined rule bodies.
"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog dated \
  --context-rules trimmed \
  "${TRIMMED_REPO}" > "$TRIMMED_OUT"

git -C "$TRIMMED_REPO" status --short > "$TRIMMED_STATUS_OUT"
if [ -s "$TRIMMED_STATUS_OUT" ]; then
  cat "$TRIMMED_STATUS_OUT" >&2
  echo "trimmed mode left uncommitted project changes" >&2
  exit 1
fi

grep -Fq "Context rules mode: trimmed (CLAUDE.md trimmed, AGENTS.md trimmed)" \
  "$TRIMMED_OUT"
for agent_file in CLAUDE.md AGENTS.md; do
  file="${TRIMMED_REPO}/${agent_file}"
  grep -Fq "<!-- BEGIN agent-guidelines project rules -->" "$file"
  grep -Fq "<!-- END agent-guidelines project rules -->" "$file"
  grep -Eq "^## Agent Guidelines Rule Selection$" "$file"
  grep -Fq "Profile: codebase. Changelog mode: date. Versioning mode: none." "$file"
  grep -Fq "| changelog-date |" "$file"
  grep -Fq '`.agent-guidelines/rules/git-workflow.md`' "$file"
  if grep -Eq "^## Git Workflow Rules$" "$file"; then
    echo "trimmed mode inlined a rule body in $agent_file" >&2
    exit 1
  fi
done
assert_agent_preamble "${TRIMMED_REPO}/CLAUDE.md"
assert_agent_preamble "${TRIMMED_REPO}/AGENTS.md"

mkdir -p "$DRY_REPO"
git -C "$DRY_REPO" init --quiet --initial-branch=main
"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog dated \
  --include-skill explain \
  --dry-run \
  "${DRY_REPO}" > "$DRY_OUT"

grep -Fq "Mode: dry-run (no files modified)" "$DRY_OUT"
grep -Fq "Would create:" "$DRY_OUT"
grep -Fq "Would update:" "$DRY_OUT"

test ! -e "${DRY_REPO}/.gittemplate"
test ! -e "${DRY_REPO}/CLAUDE.md"
test ! -e "${DRY_REPO}/AGENTS.md"
test ! -e "${DRY_REPO}/.agent-guidelines"
test ! -e "${DRY_REPO}/.agents/skills/explain"
test ! -e "${DRY_REPO}/.git/hooks/pre-commit"

git -C "$DRY_REPO" log --oneline 2>/dev/null | grep -q . && {
  echo "dry-run left a commit behind" >&2
  exit 1
}

printf 'project-setup smoke tests passed\n'
