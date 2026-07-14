#!/usr/bin/env bash
# Verifies project removal acts only on exact, recorded ownership.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-removal.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Project Removal Test"
git config --global user.email "project-removal@example.invalid"

expect_fail() {
  if "$@" >"${TMP_ROOT}/unexpected.out" 2>"${TMP_ROOT}/expected.err"; then
    echo "expected command to fail: $*" >&2
    return 1
  fi
}

init_repo() {
  local path="$1"

  mkdir -p "$path"
  git -C "$path" init -q -b main
}

# A repository with no installation history retains lookalike local state.
FOREIGN_REPO="${TMP_ROOT}/foreign-repo"
FOREIGN_RULES="${TMP_ROOT}/foreign-rules"
init_repo "$FOREIGN_REPO"
mkdir -p "$FOREIGN_RULES" \
  "${FOREIGN_REPO}/.agent-guidelines" \
  "${FOREIGN_REPO}/.agents/skills"
printf 'foreign rule\n' > "${FOREIGN_RULES}/rule.md"
ln -s "$FOREIGN_RULES" "${FOREIGN_REPO}/.agent-guidelines/rules"
printf 'foreign config\n' > "${FOREIGN_REPO}/.agent-guidelines/config"
ln -s "${ROOT_DIR}/skills/debug" \
  "${FOREIGN_REPO}/.agents/skills/explain"
printf 'CLAUDE.md\n.agent-guidelines/config\n' >> \
  "${FOREIGN_REPO}/.git/info/exclude"
git -C "$FOREIGN_REPO" config --local commit.template .gittemplate
cp -a "$FOREIGN_REPO" "${FOREIGN_REPO}.before"

"${ROOT_DIR}/project-setup.sh" --remove --dry-run "$FOREIGN_REPO" \
  >/dev/null
diff -qr "$FOREIGN_REPO" "${FOREIGN_REPO}.before" >/dev/null
"${ROOT_DIR}/project-setup.sh" --remove "$FOREIGN_REPO" >/dev/null

test -L "${FOREIGN_REPO}/.agent-guidelines/rules"
test "$(readlink "${FOREIGN_REPO}/.agent-guidelines/rules")" = \
  "$FOREIGN_RULES"
grep -Fxq 'foreign config' "${FOREIGN_REPO}/.agent-guidelines/config"
grep -Fxq 'CLAUDE.md' "${FOREIGN_REPO}/.git/info/exclude"
grep -Fxq '.agent-guidelines/config' \
  "${FOREIGN_REPO}/.git/info/exclude"
test "$(git -C "$FOREIGN_REPO" config --local --get commit.template)" = \
  .gittemplate
test -L "${FOREIGN_REPO}/.agents/skills/explain"
test "$(readlink "${FOREIGN_REPO}/.agents/skills/explain")" = \
  "${ROOT_DIR}/skills/debug"

# New installations record each local mutation and remove exact owned state.
OWNED_REPO="${TMP_ROOT}/owned-repo"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal \
  --changelog none \
  --context-rules full \
  --include-skill explain \
  "$OWNED_REPO" >/dev/null
OWNERSHIP_DIR="${OWNED_REPO}/.git/agent-guidelines/ownership-v1"
test -f "${OWNERSHIP_DIR}/commit-template"
test -f "${OWNERSHIP_DIR}/config"
test -f "${OWNERSHIP_DIR}/exclude-claude"
test -f "${OWNERSHIP_DIR}/exclude-skills"

cp -a "$OWNED_REPO" "${OWNED_REPO}.before-dry"
"${ROOT_DIR}/project-setup.sh" --remove --dry-run "$OWNED_REPO" \
  >/dev/null
diff -qr "$OWNED_REPO" "${OWNED_REPO}.before-dry" >/dev/null
"${ROOT_DIR}/project-setup.sh" --remove "$OWNED_REPO" >/dev/null

test ! -e "${OWNED_REPO}/CLAUDE.md"
test ! -e "${OWNED_REPO}/AGENTS.md"
test ! -e "${OWNED_REPO}/.agent-guidelines"
test ! -e "${OWNED_REPO}/.agents"
test ! -e "${OWNED_REPO}/.git/agent-guidelines"
! git -C "$OWNED_REPO" config --local --get commit.template >/dev/null
! grep -Fxq 'CLAUDE.md' "${OWNED_REPO}/.git/info/exclude"
! grep -Fxq '.agents/skills/' "${OWNED_REPO}/.git/info/exclude"

# Matching legacy values are not adopted: removal preserves their prior state.
LEGACY_REPO="${TMP_ROOT}/legacy-repo"
init_repo "$LEGACY_REPO"
printf 'CLAUDE.md\n' >> "${LEGACY_REPO}/.git/info/exclude"
git -C "$LEGACY_REPO" config --local commit.template .gittemplate
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$LEGACY_REPO" >/dev/null
test ! -e \
  "${LEGACY_REPO}/.git/agent-guidelines/ownership-v1/exclude-claude"
test ! -e \
  "${LEGACY_REPO}/.git/agent-guidelines/ownership-v1/commit-template"
"${ROOT_DIR}/project-setup.sh" --remove "$LEGACY_REPO" >/dev/null
grep -Fxq 'CLAUDE.md' "${LEGACY_REPO}/.git/info/exclude"
test "$(git -C "$LEGACY_REPO" config --local --get commit.template)" = \
  .gittemplate

# Any change to recorded state stops the whole removal before hooks, context,
# excludes, or local state are modified.
MISMATCH_REPO="${TMP_ROOT}/mismatch-repo"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$MISMATCH_REPO" >/dev/null
printf 'user edit\n' >> "${MISMATCH_REPO}/.agent-guidelines/config"
cp -a "$MISMATCH_REPO" "${MISMATCH_REPO}.before"
expect_fail "${ROOT_DIR}/project-setup.sh" --remove "$MISMATCH_REPO"
diff -qr "$MISMATCH_REPO" "${MISMATCH_REPO}.before" >/dev/null

DUPLICATE_REPO="${TMP_ROOT}/duplicate-exclude-repo"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$DUPLICATE_REPO" >/dev/null
printf 'CLAUDE.md\n' >> "${DUPLICATE_REPO}/.git/info/exclude"
cp -a "$DUPLICATE_REPO" "${DUPLICATE_REPO}.before"
expect_fail "${ROOT_DIR}/project-setup.sh" --remove "$DUPLICATE_REPO"
diff -qr "$DUPLICATE_REPO" "${DUPLICATE_REPO}.before" >/dev/null

# Symlinked write targets fail before repository creation and preserve their
# external payloads.
EXTERNAL_CONFIG="${TMP_ROOT}/external-config"
CONFIG_LINK_REPO="${TMP_ROOT}/config-link-repo"
mkdir -p "${CONFIG_LINK_REPO}/.agent-guidelines"
printf 'external config\n' > "$EXTERNAL_CONFIG"
cp -a "$EXTERNAL_CONFIG" "${EXTERNAL_CONFIG}.before"
ln -s "$EXTERNAL_CONFIG" \
  "${CONFIG_LINK_REPO}/.agent-guidelines/config"
expect_fail "${ROOT_DIR}/project-setup.sh" "$CONFIG_LINK_REPO"
cmp -s "$EXTERNAL_CONFIG" "${EXTERNAL_CONFIG}.before"
test ! -e "${CONFIG_LINK_REPO}/.git"

printf 'project removal safety tests passed\n'
