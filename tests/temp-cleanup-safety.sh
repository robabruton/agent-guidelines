#!/usr/bin/env bash
# Verifies runtime scratch paths are removed after failures and signals.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-temp-cleanup.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

expect_status() {
  local expected="$1"
  shift
  local status=0

  "$@" || status=$?
  if [ "$status" -ne "$expected" ]; then
    echo "expected status $expected, got $status: $*" >&2
    return 1
  fi
}

assert_runtime_dirs_absent() {
  local parent="$1"

  if find "$parent" -mindepth 1 -maxdepth 1 \
    -name 'agent-guidelines-runtime.*' -print -quit | grep -q .; then
    echo "runtime scratch directory remains below $parent" >&2
    return 1
  fi
}

FAILURE_TMP="${TMP_ROOT}/failure-tmp"
FAILURE_LOG="${TMP_ROOT}/failure-paths"
mkdir -p "$FAILURE_TMP"
expect_status 27 env ROOT_DIR="$ROOT_DIR" TEST_TMP="$FAILURE_TMP" \
  TEST_LOG="$FAILURE_LOG" bash -c '
    set -euo pipefail
    . "$ROOT_DIR/lib/safe-mutations.sh"
    export TMPDIR="$TEST_TMP"
    agent_guidelines_runtime_begin
    external="$(mktemp -d "$TEST_TMP/external.XXXXXX")"
    agent_guidelines_runtime_register_path "$external"
    printf "%s\n%s\n" "$TMPDIR" "$external" > "$TEST_LOG"
    : > "$TMPDIR/scratch"
    exit 27
  '
while IFS= read -r path; do
  test ! -e "$path"
done < "$FAILURE_LOG"
assert_runtime_dirs_absent "$FAILURE_TMP"

SIGNAL_TMP="${TMP_ROOT}/signal-tmp"
SIGNAL_LOG="${TMP_ROOT}/signal-path"
mkdir -p "$SIGNAL_TMP"
expect_status 143 env ROOT_DIR="$ROOT_DIR" TEST_TMP="$SIGNAL_TMP" \
  TEST_LOG="$SIGNAL_LOG" bash -c '
    set -euo pipefail
    . "$ROOT_DIR/lib/safe-mutations.sh"
    export TMPDIR="$TEST_TMP"
    agent_guidelines_runtime_begin
    printf "%s\n" "$TMPDIR" > "$TEST_LOG"
    : > "$TMPDIR/scratch"
    kill -TERM "$$"
  '
test ! -e "$(<"$SIGNAL_LOG")"
assert_runtime_dirs_absent "$SIGNAL_TMP"

TRANSACTION_TMP="${TMP_ROOT}/transaction-tmp"
TRANSACTION_LOG="${TMP_ROOT}/transaction-paths"
mkdir -p "$TRANSACTION_TMP"
expect_status 28 env ROOT_DIR="$ROOT_DIR" TEST_TMP="$TRANSACTION_TMP" \
  TEST_LOG="$TRANSACTION_LOG" bash -c '
    set -euo pipefail
    . "$ROOT_DIR/lib/safe-mutations.sh"
    export TMPDIR="$TEST_TMP"
    agent_guidelines_runtime_begin
    agent_guidelines_transaction_begin
    printf "%s\n%s\n" \
      "$TMPDIR" "$AGENT_GUIDELINES_TRANSACTION_DIR" > "$TEST_LOG"
    exit 28
  '
while IFS= read -r path; do
  test ! -e "$path"
done < "$TRANSACTION_LOG"
assert_runtime_dirs_absent "$TRANSACTION_TMP"

ENTRYPOINT_TMP="${TMP_ROOT}/entrypoint-tmp"
ENTRYPOINT_HOME="${TMP_ROOT}/entrypoint-home"
mkdir -p "$ENTRYPOINT_TMP" "$ENTRYPOINT_HOME"
expect_status 1 env HOME="$ENTRYPOINT_HOME" TMPDIR="$ENTRYPOINT_TMP" \
  "${ROOT_DIR}/setup.sh" --install --remove --no-color
assert_runtime_dirs_absent "$ENTRYPOINT_TMP"
expect_status 1 env HOME="$ENTRYPOINT_HOME" TMPDIR="$ENTRYPOINT_TMP" \
  "${ROOT_DIR}/project-setup.sh" target-one target-two
assert_runtime_dirs_absent "$ENTRYPOINT_TMP"

printf 'temporary cleanup safety tests passed\n'
