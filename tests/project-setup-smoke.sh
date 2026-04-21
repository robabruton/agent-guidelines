#!/usr/bin/env bash
# Verifies the target repository setup command in temporary repositories.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-tests.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

SYMLINK_REPO="${TMP_ROOT}/symlink-repo"
COPY_REPO="${TMP_ROOT}/copy-repo"
SYMLINK_FIRST_OUT="${TMP_ROOT}/symlink-first.out"
SYMLINK_SECOND_OUT="${TMP_ROOT}/symlink-second.out"
SYMLINK_STATUS_OUT="${TMP_ROOT}/symlink-status.out"
COPY_OUT="${TMP_ROOT}/copy.out"
COPY_STATUS_OUT="${TMP_ROOT}/copy-status.out"

"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog date \
  "${SYMLINK_REPO}" > "$SYMLINK_FIRST_OUT"

git -C "$SYMLINK_REPO" status --short > "$SYMLINK_STATUS_OUT"
if [ -s "$SYMLINK_STATUS_OUT" ]; then
  cat "$SYMLINK_STATUS_OUT" >&2
  echo "symlink mode left uncommitted project changes" >&2
  exit 1
fi

test -L "${SYMLINK_REPO}/.agent-guidelines/rules"
test -f "${SYMLINK_REPO}/CLAUDE.md"
test -f "${SYMLINK_REPO}/AGENTS.md"
test -f "${SYMLINK_REPO}/.git/hooks/pre-commit"
grep -Fq "Changelog mode: date" "$SYMLINK_FIRST_OUT"
grep -Fq "# Date-Based Changelog Rules" "${SYMLINK_REPO}/CLAUDE.md"

"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog date \
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
  --changelog versioned \
  --rules-source copy \
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
grep -Fq "# Semantic Versioning Rules" "${COPY_REPO}/AGENTS.md"

printf 'project-setup smoke tests passed\n'
