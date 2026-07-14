#!/usr/bin/env bash
# Verifies project setup records only the local state it creates.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-ownership.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Project Ownership Test"
git config --global user.email "project-ownership@example.invalid"

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

sha256_file() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{ print $1 }'
  else
    shasum -a 256 "$path" | awk '{ print $1 }'
  fi
}

# New local mutations receive exact ownership records.
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
grep -Fxq 'created=.gittemplate' \
  "${OWNERSHIP_DIR}/commit-template"
config_hash="$(sha256_file "${OWNED_REPO}/.agent-guidelines/config")"
grep -Fxq "sha256=${config_hash}" "${OWNERSHIP_DIR}/config"

# A requested config change updates only state that is still exactly owned.
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$OWNED_REPO" >/dev/null
config_hash="$(sha256_file "${OWNED_REPO}/.agent-guidelines/config")"
grep -Fxq "sha256=${config_hash}" "${OWNERSHIP_DIR}/config"

# Matching legacy values remain unowned instead of being silently adopted.
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

# Changed recorded state is a preflight conflict, not an overwrite target.
printf 'user edit\n' >> "${OWNED_REPO}/.agent-guidelines/config"
cp -a "$OWNED_REPO" "${OWNED_REPO}.before"
expect_fail "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$OWNED_REPO"
diff -qr "$OWNED_REPO" "${OWNED_REPO}.before" >/dev/null

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

EXTERNAL_TEMPLATE="${TMP_ROOT}/external-template"
TEMPLATE_LINK_REPO="${TMP_ROOT}/template-link-repo"
mkdir -p "$TEMPLATE_LINK_REPO"
printf 'external template\n' > "$EXTERNAL_TEMPLATE"
cp -a "$EXTERNAL_TEMPLATE" "${EXTERNAL_TEMPLATE}.before"
ln -s "$EXTERNAL_TEMPLATE" "${TEMPLATE_LINK_REPO}/.gittemplate"
expect_fail "${ROOT_DIR}/project-setup.sh" "$TEMPLATE_LINK_REPO"
cmp -s "$EXTERNAL_TEMPLATE" "${EXTERNAL_TEMPLATE}.before"
test ! -e "${TEMPLATE_LINK_REPO}/.git"

printf 'project ownership safety tests passed\n'
