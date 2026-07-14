#!/usr/bin/env bash
# Verifies project setup does not take ownership of an existing unborn index.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-initial.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Project Initial Test"
git config --global user.email "project-initial@example.invalid"

# An existing unborn repository with staged content fails unchanged instead of
# absorbing the entry into setup's initialization commit.
STAGED_REPO="${TMP_ROOT}/staged-unborn-repo"
mkdir -p "$STAGED_REPO"
git -C "$STAGED_REPO" init -q -b main
printf 'unrelated staged content\n' > "$STAGED_REPO/unrelated.txt"
git -C "$STAGED_REPO" add unrelated.txt
cp -a "$STAGED_REPO" "${STAGED_REPO}.before"
if "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$STAGED_REPO" >"${TMP_ROOT}/staged.out" \
  2>"${TMP_ROOT}/staged.err"; then
  echo "staged unborn repository unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'unborn target repository has staged content' \
  "${TMP_ROOT}/staged.err"
diff -qr "$STAGED_REPO" "${STAGED_REPO}.before" >/dev/null
test "$(git -C "$STAGED_REPO" diff --cached --name-only)" = unrelated.txt
! git -C "$STAGED_REPO" rev-parse --verify HEAD >/dev/null 2>&1

# Setup may configure an existing unborn repository with an empty index, but
# it leaves the repository's initial commit to its owner.
EMPTY_REPO="${TMP_ROOT}/empty-unborn-repo"
mkdir -p "$EMPTY_REPO"
git -C "$EMPTY_REPO" init -q -b main
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$EMPTY_REPO" > "${TMP_ROOT}/empty.out"
! git -C "$EMPTY_REPO" rev-parse --verify HEAD >/dev/null 2>&1
git -C "$EMPTY_REPO" diff --cached --quiet
grep -Fq \
  'initial commit because setup did not initialize the repository' \
  "${TMP_ROOT}/empty.out"
test -f "$EMPTY_REPO/README.md"
test -x "$EMPTY_REPO/.git/hooks/pre-commit"

# A repository initialized by this invocation still receives one commit with
# only the intended tracked project artifacts.
NEW_REPO="${TMP_ROOT}/new-repo"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$NEW_REPO" > "${TMP_ROOT}/new.out"
test "$(git -C "$NEW_REPO" rev-list --count HEAD)" -eq 1
test "$(git -C "$NEW_REPO" show --format= --name-only HEAD | sed '/^$/d')" = \
  $'.gitignore\n.gittemplate\nREADME.md'
git -C "$NEW_REPO" status --short > "${TMP_ROOT}/new.status"
test ! -s "${TMP_ROOT}/new.status"

printf 'project initial commit safety tests passed\n'
