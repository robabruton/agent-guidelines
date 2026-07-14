#!/usr/bin/env bash
# Verifies project setup contains repository and hook writes to the target.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-git-scope.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Project Git Scope Test"
git config --global user.email "project-git-scope@example.invalid"

init_repo() {
  local path="$1"

  mkdir -p "$path"
  git -C "$path" init -q -b main
  printf 'seed\n' > "$path/seed.txt"
  git -C "$path" add seed.txt
  git -C "$path" commit -q -m "chore: seed fixture"
}

expect_scoped_failure() {
  local repo="$1"
  local expected="$2"
  local before="${repo}.before"

  cp -a "$repo" "$before"
  if "${ROOT_DIR}/project-setup.sh" \
    --profile minimal --changelog none --context-rules full \
    "$repo" >"${repo}.unexpected.out" 2>"${repo}.expected.err"; then
    echo "expected scoped setup failure: $repo" >&2
    return 1
  fi
  grep -Fq "$expected" "${repo}.expected.err"
  diff -qr "$repo" "$before" >/dev/null
}

# The normal repository-local hook directory remains supported.
LOCAL_REPO="${TMP_ROOT}/local-hook-repo"
init_repo "$LOCAL_REPO"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$LOCAL_REPO" > "${TMP_ROOT}/local.out"
for hook in pre-commit commit-msg pre-push; do
  test -x "$LOCAL_REPO/.git/hooks/$hook"
  grep -Fq 'BEGIN agent-guidelines' "$LOCAL_REPO/.git/hooks/$hook"
done

# An absolute shared hook path fails before either repository or shared state
# changes.
ABSOLUTE_REPO="${TMP_ROOT}/absolute-hook-repo"
ABSOLUTE_HOOKS="${TMP_ROOT}/absolute-hooks"
init_repo "$ABSOLUTE_REPO"
mkdir -p "$ABSOLUTE_HOOKS"
printf '#!/bin/sh\nprintf "shared sentinel\\n"\n' \
  > "$ABSOLUTE_HOOKS/pre-commit"
chmod +x "$ABSOLUTE_HOOKS/pre-commit"
git -C "$ABSOLUTE_REPO" config --local core.hooksPath "$ABSOLUTE_HOOKS"
cp -a "$ABSOLUTE_HOOKS" "${ABSOLUTE_HOOKS}.before"
expect_scoped_failure "$ABSOLUTE_REPO" \
  'managed hook path escapes the repository Git directory:'
diff -qr "$ABSOLUTE_HOOKS" "${ABSOLUTE_HOOKS}.before" >/dev/null
test ! -e "$ABSOLUTE_HOOKS/commit-msg"
test ! -e "$ABSOLUTE_HOOKS/pre-push"

# Worktree-relative and escaping relative hook paths are external to the Git
# metadata directory and receive the same unchanged rejection.
RELATIVE_REPO="${TMP_ROOT}/relative-hook-repo"
init_repo "$RELATIVE_REPO"
git -C "$RELATIVE_REPO" config --local core.hooksPath .githooks
expect_scoped_failure "$RELATIVE_REPO" \
  'managed hook path escapes the repository Git directory:'
test ! -e "$RELATIVE_REPO/.githooks"

ESCAPING_REPO="${TMP_ROOT}/escaping-hook-repo"
ESCAPING_HOOKS="${TMP_ROOT}/escaping-hooks"
init_repo "$ESCAPING_REPO"
mkdir -p "$ESCAPING_HOOKS"
printf 'escaping sentinel\n' > "$ESCAPING_HOOKS/sentinel"
git -C "$ESCAPING_REPO" config --local core.hooksPath ../escaping-hooks
cp -a "$ESCAPING_HOOKS" "${ESCAPING_HOOKS}.before"
expect_scoped_failure "$ESCAPING_REPO" \
  'managed hook path escapes the repository Git directory:'
diff -qr "$ESCAPING_HOOKS" "${ESCAPING_HOOKS}.before" >/dev/null

# A target below an existing worktree cannot redirect Git mutations to its
# parent repository.
PARENT_REPO="${TMP_ROOT}/parent-repo"
SUBDIR_TARGET="$PARENT_REPO/nested/project"
init_repo "$PARENT_REPO"
mkdir -p "$SUBDIR_TARGET"
printf 'nested sentinel\n' > "$SUBDIR_TARGET/sentinel"
cp -a "$PARENT_REPO" "${PARENT_REPO}.before"
if "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$SUBDIR_TARGET" >"${TMP_ROOT}/subdir.out" \
  2>"${TMP_ROOT}/subdir.err"; then
  echo "subdirectory target unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'target must be the repository worktree root' \
  "${TMP_ROOT}/subdir.err"
diff -qr "$PARENT_REPO" "${PARENT_REPO}.before" >/dev/null

# A missing nested target is rejected before setup creates the directory.
MISSING_SUBDIR="$PARENT_REPO/missing/nested-project"
cp -a "$PARENT_REPO" "${PARENT_REPO}.before-missing"
if "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$MISSING_SUBDIR" >"${TMP_ROOT}/missing-subdir.out" \
  2>"${TMP_ROOT}/missing-subdir.err"; then
  echo "missing subdirectory target unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'target must not be created below repository worktree root' \
  "${TMP_ROOT}/missing-subdir.err"
test ! -e "$MISSING_SUBDIR"
diff -qr "$PARENT_REPO" "${PARENT_REPO}.before-missing" >/dev/null

# Ambient Git path overrides cannot redirect commands away from the target.
ENV_REPO="${TMP_ROOT}/environment-repo"
ENV_GIT_DIR="${TMP_ROOT}/environment.git"
init_repo "$ENV_REPO"
git init -q --bare "$ENV_GIT_DIR"
cp -a "$ENV_REPO" "${ENV_REPO}.before"
cp -a "$ENV_GIT_DIR" "${ENV_GIT_DIR}.before"
if env GIT_DIR="$ENV_GIT_DIR" "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$ENV_REPO" >"${TMP_ROOT}/environment.out" \
  2>"${TMP_ROOT}/environment.err"; then
  echo "ambient GIT_DIR unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'GIT_DIR must be unset' "${TMP_ROOT}/environment.err"
diff -qr "$ENV_REPO" "${ENV_REPO}.before" >/dev/null
diff -qr "$ENV_GIT_DIR" "${ENV_GIT_DIR}.before" >/dev/null

printf 'project Git scope safety tests passed\n'
