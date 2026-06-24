#!/usr/bin/env bash
# Verifies the target repository setup command in temporary repositories.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-tests.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

SYMLINK_REPO="${TMP_ROOT}/symlink-repo"
COPY_REPO="${TMP_ROOT}/copy-repo"
DRY_REPO="${TMP_ROOT}/dry-repo"
SYMLINK_FIRST_OUT="${TMP_ROOT}/symlink-first.out"
SYMLINK_SECOND_OUT="${TMP_ROOT}/symlink-second.out"
SYMLINK_STATUS_OUT="${TMP_ROOT}/symlink-status.out"
COPY_OUT="${TMP_ROOT}/copy.out"
COPY_STATUS_OUT="${TMP_ROOT}/copy-status.out"
DRY_OUT="${TMP_ROOT}/dry.out"

assert_agent_rules() {
  local file="$1"
  local expected_heading="$2"

  test -f "$file"
  grep -Fq "<!-- BEGIN agent-guidelines project rules -->" "$file"
  grep -Fq "# Git Workflow Rules" "$file"
  grep -Fq "$expected_heading" "$file"
  grep -Fq "<!-- END agent-guidelines project rules -->" "$file"
}

"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog dated \
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

test -L "${SYMLINK_REPO}/.agents/skills/explain"
test ! -e "${SYMLINK_REPO}/.agents/skills/test-audit"
grep -Fq ".agents/skills/" "${SYMLINK_REPO}/.git/info/exclude"

"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog dates \
  "${SYMLINK_REPO}" > "$SYMLINK_SECOND_OUT"

git -C "$SYMLINK_REPO" status --short > "$SYMLINK_STATUS_OUT"
if [ -s "$SYMLINK_STATUS_OUT" ]; then
  cat "$SYMLINK_STATUS_OUT" >&2
  echo "second symlink run was not idempotent" >&2
  exit 1
fi

grep -Fq "Created:" "$SYMLINK_SECOND_OUT"
grep -Fq "  none" "$SYMLINK_SECOND_OUT"

"${ROOT_DIR}/project-setup.sh" \
  --profile released \
  --changelog versions \
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
