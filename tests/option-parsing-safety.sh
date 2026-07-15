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

# Bash 3.2 treats declared-but-empty arrays as unset under `set -u`.
# Guard every expansion of an array that can legitimately be empty so
# Linux runs on newer Bash cannot mask the macOS failure mode.
nounset_array_names=(
  INCLUDE_RULES EXCLUDE_RULES INCLUDE_SKILLS EXCLUDE_SKILLS HARNESSES
  REQUESTED_INCLUDE_RULES REQUESTED_EXCLUDE_RULES
  REQUESTED_INCLUDE_SKILLS REQUESTED_EXCLUDE_SKILLS
  STORED_INCLUDE_SKILLS STORED_EXCLUDE_SKILLS STORED_HARNESSES
  LOADED_HARNESSES CREATED UPDATED UNCHANGED SKIPPED WARNINGS
  INITIAL_COMMIT_PATHS seen kept candidates local_branches identifiers
  always_rules included_rules included_skills
)
for array_name in "${nounset_array_names[@]}"; do
  printf -v raw_expansion '${%s[@]}' "$array_name"
  printf -v guarded_expansion '${%s[@]+' "$array_name"
  printf -v count_expansion '${#%s[@]}' "$array_name"
  if awk \
    -v raw="$raw_expansion" \
    -v guarded="$guarded_expansion" \
    -v count="$count_expansion" '
      index($0, raw) && !index($0, guarded) { found = 1 }
      index($0, count) { found = 1 }
      END { exit found ? 0 : 1 }
    ' "${ROOT_DIR}/project-setup.sh"; then
    echo "unsafe nounset expansion for possibly empty array: $array_name" >&2
    exit 1
  fi
done

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
