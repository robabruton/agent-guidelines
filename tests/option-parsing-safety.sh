#!/usr/bin/env bash
# Verifies setup entry points reject contradictory and ambiguous arguments.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-options.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Option Parsing Test"
git config --global user.email "options@example.invalid"

expect_fail() {
  if "$@" >/dev/null 2>&1; then
    echo "expected command to fail: $*" >&2
    return 1
  fi
}

expect_fail "${ROOT_DIR}/setup.sh" --install --remove --no-color
expect_fail "${ROOT_DIR}/setup.sh" --remove --force --no-color
expect_fail "${ROOT_DIR}/setup.sh" --status \
  --backup-path "${TMP_ROOT}/backups" --no-color
expect_fail "${ROOT_DIR}/setup.sh" \
  --backup-path "${TMP_ROOT}/backups" --no-color

TARGET_ONE="${TMP_ROOT}/target-one"
TARGET_TWO="${TMP_ROOT}/target-two"
mkdir -p "$TARGET_ONE" "$TARGET_TWO"

expect_fail "${ROOT_DIR}/project-setup.sh" \
  --dry-run "$TARGET_ONE" "$TARGET_TWO"
expect_fail "${ROOT_DIR}/project-setup.sh" \
  --dry-run "$TARGET_ONE" -- "$TARGET_TWO"
expect_fail "${ROOT_DIR}/project-setup.sh" --remove --remove "$TARGET_ONE"

selection_cases=(
  "--profile|minimal"
  "--changelog|none"
  "--context-rules|compact"
  "--rules-source|symlink"
  "--skills-source|symlink"
  "--harness|codex"
  "--default-branch|main"
  "--include-rule|docstrings"
  "--exclude-rule|docstrings"
  "--include-skill|test-audit"
  "--exclude-skill|test-audit"
)
for selection_case in "${selection_cases[@]}"; do
  option="${selection_case%%|*}"
  value="${selection_case#*|}"
  expect_fail "${ROOT_DIR}/project-setup.sh" \
    --remove "$option" "$value" "$TARGET_ONE"
done

DASH_TARGET="${TMP_ROOT}/--project"
mkdir -p "$DASH_TARGET"
(
  cd "$TMP_ROOT"
  expect_fail "${ROOT_DIR}/project-setup.sh" --dry-run --project
  "${ROOT_DIR}/project-setup.sh" --dry-run -- --project >/dev/null
  expect_fail "${ROOT_DIR}/project-setup.sh" \
    --dry-run -- --project target-two
)

printf 'option parsing safety tests passed\n'
