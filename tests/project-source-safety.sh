#!/usr/bin/env bash
# Verifies catalog identifiers and project source targets stay in scope.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-sources.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Project Source Test"
git config --global user.email "project-source@example.invalid"

expect_fail() {
  if "$@" >"${TMP_ROOT}/unexpected.out" 2>"${TMP_ROOT}/expected.err"; then
    echo "expected command to fail: $*" >&2
    return 1
  fi
}

# Rule and skill identifiers are catalog keys, not filesystem paths.
case_number=0
for identifier in .. ../README /tmp/foreign x/y x--y Upper; do
  case_number=$((case_number + 1))
  target="${TMP_ROOT}/invalid-rule-${case_number}"
  expect_fail "${ROOT_DIR}/project-setup.sh" \
    --include-rule "$identifier" "$target"
  test ! -e "$target"

  target="${TMP_ROOT}/invalid-skill-${case_number}"
  expect_fail "${ROOT_DIR}/project-setup.sh" \
    --include-skill "$identifier" "$target"
  test ! -e "$target"
done

# An existing rule directory is user-owned unless it exactly matches the
# requested generated snapshot. Symlink mode does not fall back to copying.
RULE_CONFLICT="${TMP_ROOT}/rule-conflict"
mkdir -p "${RULE_CONFLICT}/.agent-guidelines/rules"
printf 'user sentinel\n' > \
  "${RULE_CONFLICT}/.agent-guidelines/rules/user-rule.md"
cp -a "$RULE_CONFLICT" "${RULE_CONFLICT}.before"
expect_fail "${ROOT_DIR}/project-setup.sh" "$RULE_CONFLICT"
diff -qr "$RULE_CONFLICT" "${RULE_CONFLICT}.before" >/dev/null
test ! -e "${RULE_CONFLICT}/.git"

# A managed parent directory cannot redirect setup writes through a symlink.
EXTERNAL_STATE="${TMP_ROOT}/external-state"
PARENT_LINK_REPO="${TMP_ROOT}/parent-link"
mkdir -p "$EXTERNAL_STATE" "$PARENT_LINK_REPO"
printf 'external sentinel\n' > "${EXTERNAL_STATE}/sentinel"
cp -a "$EXTERNAL_STATE" "${EXTERNAL_STATE}.before"
ln -s "$EXTERNAL_STATE" "${PARENT_LINK_REPO}/.agent-guidelines"
expect_fail "${ROOT_DIR}/project-setup.sh" "$PARENT_LINK_REPO"
diff -qr "$EXTERNAL_STATE" "${EXTERNAL_STATE}.before" >/dev/null
test ! -e "${PARENT_LINK_REPO}/.git"

# Existing skill directories and foreign links are conflicts in both modes.
SKILL_COPY_REPO="${TMP_ROOT}/skill-copy-conflict"
mkdir -p "${SKILL_COPY_REPO}/.agents/skills/explain"
printf 'user sentinel\n' > \
  "${SKILL_COPY_REPO}/.agents/skills/explain/user-file"
cp -a "$SKILL_COPY_REPO" "${SKILL_COPY_REPO}.before"
expect_fail "${ROOT_DIR}/project-setup.sh" \
  --skills-source copy --harness codex \
  --include-skill explain "$SKILL_COPY_REPO"
diff -qr "$SKILL_COPY_REPO" "${SKILL_COPY_REPO}.before" >/dev/null
test ! -e "${SKILL_COPY_REPO}/.git"

FOREIGN_SKILL="${TMP_ROOT}/foreign-skill"
SKILL_LINK_REPO="${TMP_ROOT}/skill-link-conflict"
mkdir -p "$FOREIGN_SKILL" "${SKILL_LINK_REPO}/.agents/skills"
printf 'foreign sentinel\n' > "${FOREIGN_SKILL}/sentinel"
ln -s "$FOREIGN_SKILL" \
  "${SKILL_LINK_REPO}/.agents/skills/explain"
cp -a "$FOREIGN_SKILL" "${FOREIGN_SKILL}.before"
expect_fail "${ROOT_DIR}/project-setup.sh" \
  --harness codex --include-skill explain "$SKILL_LINK_REPO"
diff -qr "$FOREIGN_SKILL" "${FOREIGN_SKILL}.before" >/dev/null
test ! -e "${SKILL_LINK_REPO}/.git"

# Exact generated copies remain idempotent.
COPY_REPO="${TMP_ROOT}/copy-idempotent"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal \
  --changelog none \
  --context-rules full \
  --rules-source copy \
  --skills-source copy \
  --harness codex \
  --include-skill explain \
  "$COPY_REPO" >/dev/null
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal \
  --changelog none \
  --context-rules full \
  --rules-source copy \
  --skills-source copy \
  --harness codex \
  --include-skill explain \
  "$COPY_REPO" >/dev/null
test -z "$(git -C "$COPY_REPO" status --short)"

printf 'project source safety tests passed\n'
