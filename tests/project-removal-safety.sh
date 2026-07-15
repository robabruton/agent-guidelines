#!/usr/bin/env bash
# Verifies project removal acts only on exact, recorded ownership.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-removal.XXXXXX)"

# shellcheck source=lib/safe-mutations.sh
. "${ROOT_DIR}/lib/safe-mutations.sh"

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

expect_remove_containment_failure() {
  local repo="$1"
  local external="$2"
  local label="$3"
  local repo_before="${repo}.before-containment"
  local external_before="${external}.before-containment"
  local transaction_tmp="${repo}.transaction-tmp"

  cp -a "$repo" "$repo_before"
  cp -a "$external" "$external_before"
  mkdir -p "$transaction_tmp"

  expect_fail env TMPDIR="$transaction_tmp" \
    "${ROOT_DIR}/project-setup.sh" --remove "$repo"
  grep -Fq "error: $label is a symlink:" "${TMP_ROOT}/expected.err"
  agent_guidelines_verify_copy "$repo_before" "$repo"
  agent_guidelines_verify_copy "$external_before" "$external"
  test -z "$(find "$transaction_tmp" -mindepth 1 -maxdepth 1 \
    -print -quit)"

  expect_fail "${ROOT_DIR}/project-setup.sh" --remove --dry-run "$repo"
  grep -Fq "error: $label is a symlink:" "${TMP_ROOT}/expected.err"
  agent_guidelines_verify_copy "$repo_before" "$repo"
  agent_guidelines_verify_copy "$external_before" "$external"
}

expect_remove_containment_skip() {
  local repo="$1"
  local external="$2"
  local label="$3"
  local repo_before="${repo}.before-containment"
  local external_before="${external}.before-containment"

  cp -a "$repo" "$repo_before"
  cp -a "$external" "$external_before"

  "${ROOT_DIR}/project-setup.sh" --remove --dry-run "$repo" \
    >"${TMP_ROOT}/skip.out"
  grep -Fq "$label is unowned" "${TMP_ROOT}/skip.out"
  agent_guidelines_verify_copy "$repo_before" "$repo"
  agent_guidelines_verify_copy "$external_before" "$external"

  "${ROOT_DIR}/project-setup.sh" --remove "$repo" \
    >"${TMP_ROOT}/skip.out"
  grep -Fq "$label is unowned" "${TMP_ROOT}/skip.out"
  agent_guidelines_verify_copy "$repo_before" "$repo"
  agent_guidelines_verify_copy "$external_before" "$external"
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
  --harness codex \
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

# Removal skips unowned skill-tree parents without traversing them. Both real
# and dry-run removal preserve the repository and external payload.
AGENTS_PARENT_REPO="${TMP_ROOT}/agents-parent-repo"
AGENTS_PARENT_EXTERNAL="${TMP_ROOT}/agents-parent-external"
init_repo "$AGENTS_PARENT_REPO"
mkdir -p "${AGENTS_PARENT_EXTERNAL}/skills"
ln -s "$AGENTS_PARENT_EXTERNAL" "${AGENTS_PARENT_REPO}/.agents"
ln -s "${ROOT_DIR}/skills/explain" \
  "${AGENTS_PARENT_EXTERNAL}/skills/explain"
expect_remove_containment_skip \
  "$AGENTS_PARENT_REPO" "$AGENTS_PARENT_EXTERNAL" ".agents/skills"

SKILLS_PARENT_REPO="${TMP_ROOT}/skills-parent-repo"
SKILLS_PARENT_EXTERNAL="${TMP_ROOT}/skills-parent-external"
init_repo "$SKILLS_PARENT_REPO"
mkdir -p "${SKILLS_PARENT_REPO}/.agents" \
  "${SKILLS_PARENT_EXTERNAL}/skills"
ln -s "${SKILLS_PARENT_EXTERNAL}/skills" \
  "${SKILLS_PARENT_REPO}/.agents/skills"
ln -s "${ROOT_DIR}/skills/explain" \
  "${SKILLS_PARENT_EXTERNAL}/skills/explain"
expect_remove_containment_skip \
  "$SKILLS_PARENT_REPO" "$SKILLS_PARENT_EXTERNAL" ".agents/skills"

STATE_PARENT_REPO="${TMP_ROOT}/state-parent-repo"
STATE_PARENT_EXTERNAL="${TMP_ROOT}/state-parent-external"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$STATE_PARENT_REPO" >/dev/null
mv "${STATE_PARENT_REPO}/.agent-guidelines" "$STATE_PARENT_EXTERNAL"
ln -s "$STATE_PARENT_EXTERNAL" "${STATE_PARENT_REPO}/.agent-guidelines"
expect_remove_containment_failure \
  "$STATE_PARENT_REPO" "$STATE_PARENT_EXTERNAL" ".agent-guidelines"

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
