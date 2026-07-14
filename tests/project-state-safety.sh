#!/usr/bin/env bash
# Verifies project setup loads, validates, and reconciles owned local state.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-state.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Project State Test"
git config --global user.email "project-state@example.invalid"

sha256_file() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{ print $1 }'
  else
    shasum -a 256 "$path" | awk '{ print $1 }'
  fi
}

init_repo() {
  local path="$1"

  mkdir -p "$path"
  git -C "$path" init -q -b main
  printf 'seed\n' > "$path/seed.txt"
  git -C "$path" add seed.txt
  git -C "$path" commit -q -m "chore: seed fixture"
}

refresh_config_ownership() {
  local repo="$1"
  local config="$repo/.agent-guidelines/config"
  local record="$repo/.git/agent-guidelines/ownership-v1/config"

  printf 'sha256=%s\n' "$(sha256_file "$config")" > "$record"
}

expect_unchanged_failure() {
  local repo="$1"
  local expected="$2"
  local before="${repo}.before-failure"

  cp -a "$repo" "$before"
  if "${ROOT_DIR}/project-setup.sh" "$repo" \
    >"${repo}.unexpected.out" 2>"${repo}.expected.err"; then
    echo "expected project setup to fail: $repo" >&2
    return 1
  fi
  grep -Fq "$expected" "${repo}.expected.err"
  diff -qr "$repo" "$before" >/dev/null
}

# A no-flag rerun preserves every stored scalar, selection, and managed object.
RERUN_REPO="${TMP_ROOT}/rerun-repo"
init_repo "$RERUN_REPO"
"${ROOT_DIR}/project-setup.sh" \
  --profile codebase \
  --changelog date \
  --context-rules full \
  --rules-source symlink \
  --skills-source symlink \
  --include-rule docstrings \
  --exclude-rule performance \
  --include-skill explain \
  --include-skill test-audit \
  --exclude-skill test-audit \
  "$RERUN_REPO" > "${TMP_ROOT}/first.out"

CONFIG="$RERUN_REPO/.agent-guidelines/config"
grep -Fxq 'schema=1' "$CONFIG"
grep -Fxq 'profile=codebase' "$CONFIG"
grep -Fxq 'changelog=date' "$CONFIG"
grep -Fxq 'context_rules=full' "$CONFIG"
grep -Fxq 'rules_source=symlink' "$CONFIG"
grep -Fxq 'skills_source=symlink' "$CONFIG"
grep -Fxq 'include_rule=docstrings' "$CONFIG"
grep -Fxq 'exclude_rule=performance' "$CONFIG"
grep -Fxq 'include_skill=explain' "$CONFIG"
grep -Fxq 'include_skill=test-audit' "$CONFIG"
grep -Fxq 'exclude_skill=test-audit' "$CONFIG"
test -L "$RERUN_REPO/.agents/skills/explain"
test ! -e "$RERUN_REPO/.agents/skills/test-audit"

cp -a "$RERUN_REPO" "${RERUN_REPO}.before-rerun"
"${ROOT_DIR}/project-setup.sh" "$RERUN_REPO" \
  > "${TMP_ROOT}/second.out"
diff -qr "$RERUN_REPO" "${RERUN_REPO}.before-rerun" >/dev/null
grep -Fq 'Profile: codebase' "${TMP_ROOT}/second.out"
grep -Fq 'Changelog mode: date' "${TMP_ROOT}/second.out"
grep -Fq 'Context rules mode: full' "${TMP_ROOT}/second.out"

# A named selection change removes only that owned skill and can re-enable it.
"${ROOT_DIR}/project-setup.sh" --exclude-skill explain "$RERUN_REPO" \
  > "${TMP_ROOT}/exclude.out"
test ! -e "$RERUN_REPO/.agents/skills/explain"
! grep -Fxq 'include_skill=explain' "$CONFIG"
grep -Fxq 'exclude_skill=explain' "$CONFIG"
grep -Fxq 'include_skill=test-audit' "$CONFIG"
grep -Fxq 'exclude_skill=test-audit' "$CONFIG"
! grep -Fxq '.agents/skills/' "$RERUN_REPO/.git/info/exclude"
test ! -e \
  "$RERUN_REPO/.git/agent-guidelines/ownership-v1/exclude-skills"

"${ROOT_DIR}/project-setup.sh" --include-skill explain "$RERUN_REPO" \
  > "${TMP_ROOT}/include.out"
test -L "$RERUN_REPO/.agents/skills/explain"
grep -Fxq 'include_skill=explain' "$CONFIG"
! grep -Fxq 'exclude_skill=explain' "$CONFIG"
grep -Fxq '.agents/skills/' "$RERUN_REPO/.git/info/exclude"

# Explicit source-mode changes replace only exact recorded objects and
# reconcile their owned exclude entries.
"${ROOT_DIR}/project-setup.sh" --skills-source copy "$RERUN_REPO" \
  > "${TMP_ROOT}/skills-copy.out"
test -d "$RERUN_REPO/.agents/skills/explain"
test ! -L "$RERUN_REPO/.agents/skills/explain"
grep -Fxq 'skills_source=copy' "$CONFIG"
! grep -Fxq '.agents/skills/' "$RERUN_REPO/.git/info/exclude"

TAMPERED_SKILL_REPO="${TMP_ROOT}/tampered-skill-repo"
cp -a "$RERUN_REPO" "$TAMPERED_SKILL_REPO"
printf '\ntampered copy\n' \
  >> "$TAMPERED_SKILL_REPO/.agents/skills/explain/SKILL.md"
cp -a "$TAMPERED_SKILL_REPO" "${TAMPERED_SKILL_REPO}.before"
if "${ROOT_DIR}/project-setup.sh" --skills-source symlink \
  "$TAMPERED_SKILL_REPO" >"${TMP_ROOT}/tampered-skill.out" \
  2>"${TMP_ROOT}/tampered-skill.err"; then
  echo "changed skill copy unexpectedly changed source mode" >&2
  exit 1
fi
grep -Fq 'changed from its recorded managed copy' \
  "${TMP_ROOT}/tampered-skill.err"
diff -qr "$TAMPERED_SKILL_REPO" \
  "${TAMPERED_SKILL_REPO}.before" >/dev/null

"${ROOT_DIR}/project-setup.sh" --skills-source symlink "$RERUN_REPO" \
  > "${TMP_ROOT}/skills-symlink.out"
test -L "$RERUN_REPO/.agents/skills/explain"
grep -Fxq 'skills_source=symlink' "$CONFIG"
grep -Fxq '.agents/skills/' "$RERUN_REPO/.git/info/exclude"

"${ROOT_DIR}/project-setup.sh" --rules-source copy "$RERUN_REPO" \
  > "${TMP_ROOT}/rules-copy.out"
test -d "$RERUN_REPO/.agent-guidelines/rules"
test ! -L "$RERUN_REPO/.agent-guidelines/rules"
grep -Fxq 'rules_source=copy' "$CONFIG"
grep -Fxq 'skills_source=symlink' "$CONFIG"
! grep -Fxq '.agent-guidelines/rules' \
  "$RERUN_REPO/.git/info/exclude"

TAMPERED_RULE_REPO="${TMP_ROOT}/tampered-rule-repo"
cp -a "$RERUN_REPO" "$TAMPERED_RULE_REPO"
printf '\ntampered snapshot\n' \
  >> "$TAMPERED_RULE_REPO/.agent-guidelines/rules/agent-conduct.md"
cp -a "$TAMPERED_RULE_REPO" "${TAMPERED_RULE_REPO}.before"
if "${ROOT_DIR}/project-setup.sh" --rules-source symlink \
  "$TAMPERED_RULE_REPO" >"${TMP_ROOT}/tampered-rule.out" \
  2>"${TMP_ROOT}/tampered-rule.err"; then
  echo "changed rule snapshot unexpectedly changed source mode" >&2
  exit 1
fi
grep -Fq 'changed from its managed snapshot' \
  "${TMP_ROOT}/tampered-rule.err"
diff -qr "$TAMPERED_RULE_REPO" \
  "${TAMPERED_RULE_REPO}.before" >/dev/null

"${ROOT_DIR}/project-setup.sh" --rules-source symlink "$RERUN_REPO" \
  > "${TMP_ROOT}/rules-symlink.out"
test -L "$RERUN_REPO/.agent-guidelines/rules"
grep -Fxq 'rules_source=symlink' "$CONFIG"
grep -Fxq '.agent-guidelines/rules' "$RERUN_REPO/.git/info/exclude"

# The owned versionless format migrates strictly without losing selections.
LEGACY_REPO="${TMP_ROOT}/legacy-repo"
cp -a "$RERUN_REPO" "$LEGACY_REPO"
{
  printf 'profile=codebase\n'
  printf 'changelog=date\n'
  printf 'versioning=none\n'
  printf 'context_rules=full\n'
  printf 'rules_source=symlink\n'
  printf 'skills_source=symlink\n'
  printf 'include_rules=docstrings\n'
  printf 'exclude_rules=performance\n'
  printf 'include_skills=explain test-audit\n'
  printf 'exclude_skills=test-audit\n'
} > "$LEGACY_REPO/.agent-guidelines/config"
refresh_config_ownership "$LEGACY_REPO"
"${ROOT_DIR}/project-setup.sh" "$LEGACY_REPO" \
  > "${TMP_ROOT}/legacy.out"
grep -Fxq 'schema=1' "$LEGACY_REPO/.agent-guidelines/config"
grep -Fxq 'include_skill=explain' "$LEGACY_REPO/.agent-guidelines/config"
grep -Fxq 'include_skill=test-audit' "$LEGACY_REPO/.agent-guidelines/config"
grep -Fxq 'exclude_skill=test-audit' "$LEGACY_REPO/.agent-guidelines/config"

# Owned malformed, unknown, duplicated, executable-looking, and NUL-bearing
# state fails before mutation.
UNKNOWN_SCHEMA_REPO="${TMP_ROOT}/unknown-schema-repo"
cp -a "$RERUN_REPO" "$UNKNOWN_SCHEMA_REPO"
sed 's/^schema=1$/schema=2/' \
  "$UNKNOWN_SCHEMA_REPO/.agent-guidelines/config" \
  > "${TMP_ROOT}/unknown-schema.config"
cp "${TMP_ROOT}/unknown-schema.config" \
  "$UNKNOWN_SCHEMA_REPO/.agent-guidelines/config"
refresh_config_ownership "$UNKNOWN_SCHEMA_REPO"
expect_unchanged_failure "$UNKNOWN_SCHEMA_REPO" \
  'unsupported setup state schema: 2'

UNKNOWN_KEY_REPO="${TMP_ROOT}/unknown-key-repo"
cp -a "$RERUN_REPO" "$UNKNOWN_KEY_REPO"
printf 'unknown_key=value\n' >> "$UNKNOWN_KEY_REPO/.agent-guidelines/config"
refresh_config_ownership "$UNKNOWN_KEY_REPO"
expect_unchanged_failure "$UNKNOWN_KEY_REPO" 'unknown setup state key: unknown_key'

DUPLICATE_REPO="${TMP_ROOT}/duplicate-repo"
cp -a "$RERUN_REPO" "$DUPLICATE_REPO"
printf 'profile=codebase\n' >> "$DUPLICATE_REPO/.agent-guidelines/config"
refresh_config_ownership "$DUPLICATE_REPO"
expect_unchanged_failure "$DUPLICATE_REPO" 'duplicate setup state key: profile'

DUPLICATE_SELECTION_REPO="${TMP_ROOT}/duplicate-selection-repo"
cp -a "$RERUN_REPO" "$DUPLICATE_SELECTION_REPO"
printf 'include_skill=explain\n' \
  >> "$DUPLICATE_SELECTION_REPO/.agent-guidelines/config"
refresh_config_ownership "$DUPLICATE_SELECTION_REPO"
expect_unchanged_failure "$DUPLICATE_SELECTION_REPO" \
  'duplicate stored include_skill: explain'

SHELL_VALUE_REPO="${TMP_ROOT}/shell-value-repo"
SHELL_SENTINEL="${TMP_ROOT}/shell-value-ran"
cp -a "$RERUN_REPO" "$SHELL_VALUE_REPO"
sed "s|^profile=.*|profile=\$(touch $SHELL_SENTINEL)|" \
  "$SHELL_VALUE_REPO/.agent-guidelines/config" \
  > "${TMP_ROOT}/shell-value.config"
cp "${TMP_ROOT}/shell-value.config" \
  "$SHELL_VALUE_REPO/.agent-guidelines/config"
refresh_config_ownership "$SHELL_VALUE_REPO"
expect_unchanged_failure "$SHELL_VALUE_REPO" 'invalid stored profile:'
test ! -e "$SHELL_SENTINEL"

NUL_REPO="${TMP_ROOT}/nul-repo"
cp -a "$RERUN_REPO" "$NUL_REPO"
printf '\0' >> "$NUL_REPO/.agent-guidelines/config"
refresh_config_ownership "$NUL_REPO"
expect_unchanged_failure "$NUL_REPO" 'setup state contains NUL data:'

# Duplicate CLI operations fail before target mutation.
CLI_DUPLICATE_REPO="${TMP_ROOT}/cli-duplicate-repo"
cp -a "$RERUN_REPO" "$CLI_DUPLICATE_REPO"
cp -a "$CLI_DUPLICATE_REPO" "${CLI_DUPLICATE_REPO}.before"
if "${ROOT_DIR}/project-setup.sh" \
  --include-skill explain --include-skill explain \
  "$CLI_DUPLICATE_REPO" >"${TMP_ROOT}/cli-duplicate.out" \
  2>"${TMP_ROOT}/cli-duplicate.err"; then
  echo "duplicate CLI selection unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'duplicate --include-skill value: explain' \
  "${TMP_ROOT}/cli-duplicate.err"
diff -qr "$CLI_DUPLICATE_REPO" "${CLI_DUPLICATE_REPO}.before" >/dev/null

# A fresh dry run previews local state without requiring Git metadata.
FRESH_DRY_REPO="${TMP_ROOT}/fresh-dry-repo"
mkdir -p "$FRESH_DRY_REPO"
"${ROOT_DIR}/project-setup.sh" --dry-run --profile minimal \
  "$FRESH_DRY_REPO" >"${TMP_ROOT}/fresh-dry.out" \
  2>"${TMP_ROOT}/fresh-dry.err"
test ! -s "${TMP_ROOT}/fresh-dry.err"
test -z "$(find "$FRESH_DRY_REPO" -mindepth 1 -print -quit)"
grep -Fq 'Default branch policy: main' "${TMP_ROOT}/fresh-dry.out"
grep -Fq 'Would create:' "${TMP_ROOT}/fresh-dry.out"

printf 'project state safety tests passed\n'
