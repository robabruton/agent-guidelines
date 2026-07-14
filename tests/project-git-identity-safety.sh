#!/usr/bin/env bash
# Verifies project setup resolves and reuses identity from the target context.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-git-identity.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

EMPTY_HOME="${TMP_ROOT}/empty-home"
GLOBAL_HOME="${TMP_ROOT}/global-home"
mkdir -p "$EMPTY_HOME" "$GLOBAL_HOME"
HOME="$GLOBAL_HOME" git config --global user.name "Global Fixture"
HOME="$GLOBAL_HOME" git config --global user.email \
  "global-fixture@example.invalid"

init_without_identity() {
  local path="$1"

  mkdir -p "$path"
  HOME="$EMPTY_HOME" git -C "$path" init -q -b main
  printf 'seed\n' > "$path/seed.txt"
  HOME="$EMPTY_HOME" git -C "$path" add seed.txt
  HOME="$EMPTY_HOME" \
    GIT_AUTHOR_NAME="Seed Fixture" \
    GIT_AUTHOR_EMAIL="seed-fixture@example.invalid" \
    GIT_COMMITTER_NAME="Seed Fixture" \
    GIT_COMMITTER_EMAIL="seed-fixture@example.invalid" \
    git -C "$path" commit -q -m "chore: seed fixture"
}

# A valid target-local identity succeeds even when the caller and HOME provide
# no identity.
TARGET_ID_REPO="${TMP_ROOT}/target-identity-repo"
NON_REPO_CALLER="${TMP_ROOT}/non-repository-caller"
init_without_identity "$TARGET_ID_REPO"
mkdir -p "$NON_REPO_CALLER"
HOME="$EMPTY_HOME" git -C "$TARGET_ID_REPO" config --local \
  user.name "Target Fixture"
HOME="$EMPTY_HOME" git -C "$TARGET_ID_REPO" config --local \
  user.email "target-fixture@example.invalid"
(
  cd "$NON_REPO_CALLER"
  HOME="$EMPTY_HOME" "${ROOT_DIR}/project-setup.sh" \
    --profile minimal --changelog none --context-rules full \
    "$TARGET_ID_REPO"
) > "${TMP_ROOT}/target-identity.out"
grep -Fq 'Git user: Target Fixture <target-fixture@example.invalid>' \
  "${TMP_ROOT}/target-identity.out"

# Caller-local identity cannot satisfy a target that has no effective
# identity. Rejection occurs before target mutation.
CALLER_REPO="${TMP_ROOT}/caller-identity-repo"
MISSING_ID_REPO="${TMP_ROOT}/missing-target-identity-repo"
init_without_identity "$CALLER_REPO"
init_without_identity "$MISSING_ID_REPO"
HOME="$EMPTY_HOME" git -C "$CALLER_REPO" config --local \
  user.name "Caller Fixture"
HOME="$EMPTY_HOME" git -C "$CALLER_REPO" config --local \
  user.email "caller-fixture@example.invalid"
cp -a "$MISSING_ID_REPO" "${MISSING_ID_REPO}.before"
if (
  cd "$CALLER_REPO"
  HOME="$EMPTY_HOME" "${ROOT_DIR}/project-setup.sh" \
    --profile minimal --changelog none --context-rules full \
    "$MISSING_ID_REPO"
) > "${TMP_ROOT}/caller-identity.out" \
  2> "${TMP_ROOT}/caller-identity.err"; then
  echo "caller identity unexpectedly satisfied the target" >&2
  exit 1
fi
grep -Fq 'git user.name and user.email must be configured' \
  "${TMP_ROOT}/caller-identity.err"
diff -qr "$MISSING_ID_REPO" "${MISSING_ID_REPO}.before" >/dev/null

# A new repository uses and reports the exact identity resolved during
# preflight for both author and committer fields.
NEW_REPO="${TMP_ROOT}/new-repo"
HOME="$GLOBAL_HOME" "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$NEW_REPO" > "${TMP_ROOT}/new-repo.out"
grep -Fq 'Git user: Global Fixture <global-fixture@example.invalid>' \
  "${TMP_ROOT}/new-repo.out"
test "$(HOME="$GLOBAL_HOME" git -C "$NEW_REPO" log -1 \
  --format='%an <%ae>')" = \
  'Global Fixture <global-fixture@example.invalid>'
test "$(HOME="$GLOBAL_HOME" git -C "$NEW_REPO" log -1 \
  --format='%cn <%ce>')" = \
  'Global Fixture <global-fixture@example.invalid>'

printf 'project Git identity safety tests passed\n'
