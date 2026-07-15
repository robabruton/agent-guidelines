#!/usr/bin/env bash
# Verifies deterministic profile and changelog inference from current files.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-profile-inference.XXXXXX)"
TEST_HOME="${TMP_ROOT}/home"

trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TEST_HOME"
HOME="$TEST_HOME" git config --global user.name "Test User"
HOME="$TEST_HOME" git config --global user.email "test@example.invalid"

# Requires one fixture to resolve to the documented selections.
assert_selection() {
  local fixture="$1"
  local expected_profile="$2"
  local expected_changelog="$3"
  local output="${fixture}.out"

  HOME="$TEST_HOME" "${ROOT_DIR}/project-setup.sh" --dry-run "$fixture" \
    > "$output"
  grep -Fq "Profile: ${expected_profile}" "$output"
  grep -Fq "Changelog mode: ${expected_changelog}" "$output"
}

EMPTY_REPO="${TMP_ROOT}/empty"
mkdir -p "$EMPTY_REPO"
assert_selection "$EMPTY_REPO" minimal none

SOURCE_REPO="${TMP_ROOT}/source"
mkdir -p "$SOURCE_REPO"
printf 'print("fixture")\n' > "${SOURCE_REPO}/app.py"
assert_selection "$SOURCE_REPO" codebase none

MANIFEST_REPO="${TMP_ROOT}/manifest"
mkdir -p "$MANIFEST_REPO"
printf '{}\n' > "${MANIFEST_REPO}/package.json"
assert_selection "$MANIFEST_REPO" released version

VERSION_REPO="${TMP_ROOT}/version-file"
mkdir -p "$VERSION_REPO"
printf '1.2.3\n' > "${VERSION_REPO}/VERSION"
assert_selection "$VERSION_REPO" released version

VERSIONED_CHANGELOG_REPO="${TMP_ROOT}/versioned-changelog"
mkdir -p "$VERSIONED_CHANGELOG_REPO"
printf '# Changelog\n\n## [1.2.3] - 2026-01-01\n' \
  > "${VERSIONED_CHANGELOG_REPO}/CHANGELOG.md"
assert_selection "$VERSIONED_CHANGELOG_REPO" released version

DATED_CHANGELOG_REPO="${TMP_ROOT}/dated-changelog"
mkdir -p "$DATED_CHANGELOG_REPO"
printf '# Changelog\n\n## 2026-01-01\n' \
  > "${DATED_CHANGELOG_REPO}/CHANGELOG.md"
assert_selection "$DATED_CHANGELOG_REPO" minimal date

MIXED_CHANGELOG_REPO="${TMP_ROOT}/mixed-changelog"
mkdir -p "$MIXED_CHANGELOG_REPO"
printf '# Changelog\n\n## 2026-01-01\n\n## [1.2.3] - 2026-01-01\n' \
  > "${MIXED_CHANGELOG_REPO}/CHANGELOG.md"
assert_selection "$MIXED_CHANGELOG_REPO" released version

TAG_REPO="${TMP_ROOT}/tag-only"
mkdir -p "$TAG_REPO"
git -C "$TAG_REPO" init -q --initial-branch=main
HOME="$TEST_HOME" git -C "$TAG_REPO" commit -q --allow-empty \
  -m "test: seed tag fixture"
git -C "$TAG_REPO" tag v1.2.3
assert_selection "$TAG_REPO" minimal none

printf 'project profile inference safety tests passed\n'
