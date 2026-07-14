#!/usr/bin/env bash
# Verifies late staged-repository failures retain complete Git recovery state.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-recovery.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Project Recovery Test"
git config --global user.email "project-recovery@example.invalid"

REAL_CP="$(command -v cp)"
REAL_MV="$(command -v mv)"

# A final verification failure moves the installed Git directory back to the
# reported staged location before target rollback.
VERIFY_REPO="${TMP_ROOT}/verify-failed-repo"
CP_SHIM_DIR="${TMP_ROOT}/cp-shim"
mkdir -p "$CP_SHIM_DIR"
{
  printf '#!/bin/sh\n'
  printf '[ "$2" != "$FAIL_CP_SOURCE" ] || exit 75\n'
  printf 'exec "$REAL_CP" "$@"\n'
} > "$CP_SHIM_DIR/cp"
chmod +x "$CP_SHIM_DIR/cp"
if env \
  FAIL_CP_SOURCE="$VERIFY_REPO/.git" \
  REAL_CP="$REAL_CP" \
  PATH="$CP_SHIM_DIR:$PATH" \
  "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$VERIFY_REPO" >"${TMP_ROOT}/verify-failed.out" \
  2>"${TMP_ROOT}/verify-failed.err"; then
  echo "injected final verification failure unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'could not verify the installed Git directory; staged Git retained:' \
  "${TMP_ROOT}/verify-failed.err"
verify_recovery_git_dir="$(sed -n \
  's/^error: recovery state retained: staged Git directory: //p' \
  "${TMP_ROOT}/verify-failed.err" | tail -1)"
test -d "$verify_recovery_git_dir"
test ! -e "$VERIFY_REPO/.git"
test -z "$(find "$VERIFY_REPO" -mindepth 1 -print -quit)"
git --git-dir="$verify_recovery_git_dir" fsck --full
test "$(git --git-dir="$verify_recovery_git_dir" rev-list --count HEAD)" \
  -eq 1

# If restoring the staged path also fails, rollback retains both the installed
# Git directory and the transaction's complete recovery copy.
RETAIN_REPO="${TMP_ROOT}/retain-failed-repo"
RETAIN_SHIM_DIR="${TMP_ROOT}/retain-shim"
mkdir -p "$RETAIN_SHIM_DIR"
cp "$CP_SHIM_DIR/cp" "$RETAIN_SHIM_DIR/cp"
{
  printf '#!/bin/sh\n'
  printf '[ "$1" != "$FAIL_MV_SOURCE" ] || exit 76\n'
  printf 'exec "$REAL_MV" "$@"\n'
} > "$RETAIN_SHIM_DIR/mv"
chmod +x "$RETAIN_SHIM_DIR/cp" "$RETAIN_SHIM_DIR/mv"
if env \
  FAIL_CP_SOURCE="$RETAIN_REPO/.git" \
  FAIL_MV_SOURCE="$RETAIN_REPO/.git" \
  REAL_CP="$REAL_CP" \
  REAL_MV="$REAL_MV" \
  PATH="$RETAIN_SHIM_DIR:$PATH" \
  "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$RETAIN_REPO" >"${TMP_ROOT}/retain-failed.out" \
  2>"${TMP_ROOT}/retain-failed.err"; then
  echo "injected recovery restoration failure unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'could not verify or restore the installed Git directory:' \
  "${TMP_ROOT}/retain-failed.err"
grep -Fq 'transaction rollback incomplete; recovery directory:' \
  "${TMP_ROOT}/retain-failed.err"
transaction_entry="$(sed -n \
  's/^error: recovery state retained: installed Git directory: .*; transaction recovery entry: //p' \
  "${TMP_ROOT}/retain-failed.err" | tail -1)"
test -d "$RETAIN_REPO/.git"
test -d "$transaction_entry/intended"
git --git-dir="$RETAIN_REPO/.git" fsck --full
git --git-dir="$transaction_entry/intended" fsck --full

printf 'project Git recovery safety tests passed\n'
