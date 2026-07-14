#!/usr/bin/env bash
# Verifies managed-block writes reject symlinks and malformed markers.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-managed-blocks.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

# shellcheck source=lib/assemble-rules.sh
. "${ROOT_DIR}/lib/assemble-rules.sh"

expect_fail() {
  if "$@"; then
    echo "expected command to fail: $*" >&2
    return 1
  fi
}

write_block() {
  local path="$1"

  {
    printf '%s\n\n' "$AGENT_GUIDELINES_MARKER_BEGIN"
    printf '## Managed replacement\n'
    printf '%s\n' "$AGENT_GUIDELINES_MARKER_END"
  } > "$path"
}

BLOCK_FILE="${TMP_ROOT}/block.md"
write_block "$BLOCK_FILE"

# A managed file symlink must never redirect an update into another file.
EXTERNAL_FILE="${TMP_ROOT}/external.md"
SYMLINK_TARGET="${TMP_ROOT}/linked.md"
printf 'external sentinel\n' > "$EXTERNAL_FILE"
cp -a "$EXTERNAL_FILE" "${EXTERNAL_FILE}.before"
ln -s "$EXTERNAL_FILE" "$SYMLINK_TARGET"

expect_fail agent_guidelines_update_managed_block \
  "$SYMLINK_TARGET" "$BLOCK_FILE"
cmp -s "$EXTERNAL_FILE" "${EXTERNAL_FILE}.before"
test -L "$SYMLINK_TARGET"

# Partial and duplicate marker pairs are corruption, not append/replace cases.
for case_name in begin-only end-only duplicate-begin duplicate-end reversed; do
  target="${TMP_ROOT}/${case_name}.md"
  case "$case_name" in
    begin-only)
      printf '%s\nuser sentinel\n' "$AGENT_GUIDELINES_MARKER_BEGIN" > "$target"
      ;;
    end-only)
      printf 'user sentinel\n%s\n' "$AGENT_GUIDELINES_MARKER_END" > "$target"
      ;;
    duplicate-begin)
      printf '%s\nuser sentinel\n%s\n%s\n' \
        "$AGENT_GUIDELINES_MARKER_BEGIN" \
        "$AGENT_GUIDELINES_MARKER_BEGIN" \
        "$AGENT_GUIDELINES_MARKER_END" > "$target"
      ;;
    duplicate-end)
      printf '%s\nuser sentinel\n%s\n%s\n' \
        "$AGENT_GUIDELINES_MARKER_BEGIN" \
        "$AGENT_GUIDELINES_MARKER_END" \
        "$AGENT_GUIDELINES_MARKER_END" > "$target"
      ;;
    reversed)
      printf '%s\nuser sentinel\n%s\n' \
        "$AGENT_GUIDELINES_MARKER_END" \
        "$AGENT_GUIDELINES_MARKER_BEGIN" > "$target"
      ;;
  esac

  cp -a "$target" "${target}.before"
  expect_fail agent_guidelines_update_managed_block "$target" "$BLOCK_FILE"
  cmp -s "$target" "${target}.before"
  expect_fail agent_guidelines_remove_managed_block "$target"
  cmp -s "$target" "${target}.before"
done

# Hook installation must preflight every marker pair before changing the hook.
export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Managed Block Test"
git config --global user.email "managed-block@example.invalid"

HOOK_REPO="${TMP_ROOT}/hook-repo"
mkdir -p "$HOOK_REPO"
git -C "$HOOK_REPO" init -q -b main
printf 'seed\n' > "${HOOK_REPO}/seed.txt"
git -C "$HOOK_REPO" add seed.txt
git -C "$HOOK_REPO" commit -q -m "chore: seed fixture"

"${ROOT_DIR}/project-setup.sh" --profile minimal "$HOOK_REPO" >/dev/null

HOOK_FILE="${HOOK_REPO}/.git/hooks/pre-commit"
HOOK_END="# END agent-guidelines main-branch guard"
awk -v marker="$HOOK_END" '$0 != marker' "$HOOK_FILE" > "${HOOK_FILE}.tmp"
mv "${HOOK_FILE}.tmp" "$HOOK_FILE"
printf 'USER_HOOK_SENTINEL\n' >> "$HOOK_FILE"
cp -a "$HOOK_FILE" "${HOOK_FILE}.before"

expect_fail "${ROOT_DIR}/project-setup.sh" --profile minimal "$HOOK_REPO"
cmp -s "$HOOK_FILE" "${HOOK_FILE}.before"
grep -Fq 'USER_HOOK_SENTINEL' "$HOOK_FILE"

printf 'managed-block safety tests passed\n'
