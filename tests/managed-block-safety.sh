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

# Valid replacements and removals are atomic and preserve the target mode.
ATOMIC_TARGET="${TMP_ROOT}/atomic.md"
{
  printf 'user sentinel\n\n'
  printf '%s\n' "$AGENT_GUIDELINES_MARKER_BEGIN"
  printf 'old managed content\n'
  printf '%s\n' "$AGENT_GUIDELINES_MARKER_END"
} > "$ATOMIC_TARGET"
chmod 640 "$ATOMIC_TARGET"
test "$(agent_guidelines_update_managed_block \
  "$ATOMIC_TARGET" "$BLOCK_FILE")" = updated
grep -Fxq 'user sentinel' "$ATOMIC_TARGET"
grep -Fxq '## Managed replacement' "$ATOMIC_TARGET"
test "$(agent_guidelines_stat_signature "$ATOMIC_TARGET" | \
  cut -d: -f1)" = 640
test "$(agent_guidelines_remove_managed_block "$ATOMIC_TARGET")" = cleared
grep -Fxq 'user sentinel' "$ATOMIC_TARGET"
test "$(agent_guidelines_stat_signature "$ATOMIC_TARGET" | \
  cut -d: -f1)" = 640

GENERATED_TARGET="${TMP_ROOT}/generated.md"
cp -a "$BLOCK_FILE" "$GENERATED_TARGET"
test "$(agent_guidelines_remove_managed_block "$GENERATED_TARGET")" = removed
test ! -e "$GENERATED_TARGET"

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

# A malformed late global context target stops before any earlier links or
# contexts are created.
export HOME="${TMP_ROOT}/late-global-home"
mkdir -p "${HOME}/.codex"
LATE_CONTEXT="${HOME}/.codex/AGENTS.md"
printf '%s\nlate sentinel\n' \
  "$AGENT_GUIDELINES_MARKER_BEGIN" > "$LATE_CONTEXT"
cp -a "$LATE_CONTEXT" "${LATE_CONTEXT}.before"
expect_fail "${ROOT_DIR}/setup.sh" --install --no-color
cmp -s "$LATE_CONTEXT" "${LATE_CONTEXT}.before"
test ! -e "${HOME}/.agent-guidelines/rules"
test ! -e "${HOME}/.claude/skills/agent-memory"

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
test -x "$HOOK_FILE"
test "$(agent_guidelines_stat_signature "$HOOK_FILE" | cut -d: -f1)" = 755
HOOK_END="# END agent-guidelines main-branch guard"
awk -v marker="$HOOK_END" '$0 != marker' "$HOOK_FILE" > "${HOOK_FILE}.tmp"
mv "${HOOK_FILE}.tmp" "$HOOK_FILE"
printf 'USER_HOOK_SENTINEL\n' >> "$HOOK_FILE"
cp -a "$HOOK_FILE" "${HOOK_FILE}.before"

expect_fail "${ROOT_DIR}/project-setup.sh" --profile minimal "$HOOK_REPO"
cmp -s "$HOOK_FILE" "${HOOK_FILE}.before"
grep -Fq 'USER_HOOK_SENTINEL' "$HOOK_FILE"

# A runtime failure after multiple valid writes restores every earlier target.
TRANSACTION_ONE="${TMP_ROOT}/transaction-one.md"
TRANSACTION_TWO="${TMP_ROOT}/transaction-two.md"
TRANSACTION_DIR_LOG="${TMP_ROOT}/transaction-dir"
for target in "$TRANSACTION_ONE" "$TRANSACTION_TWO"; do
  {
    printf '%s\n' "$AGENT_GUIDELINES_MARKER_BEGIN"
    printf 'original managed content\n'
    printf '%s\n' "$AGENT_GUIDELINES_MARKER_END"
  } > "$target"
  cp -a "$target" "${target}.before"
done

transaction_status=0
(
  agent_guidelines_transaction_begin
  printf '%s\n' "$AGENT_GUIDELINES_TRANSACTION_DIR" > "$TRANSACTION_DIR_LOG"
  agent_guidelines_update_managed_block \
    "$TRANSACTION_ONE" "$BLOCK_FILE" >/dev/null
  agent_guidelines_update_managed_block \
    "$TRANSACTION_TWO" "$BLOCK_FILE" >/dev/null
  exit 27
) || transaction_status=$?
test "$transaction_status" -eq 27
cmp -s "$TRANSACTION_ONE" "${TRANSACTION_ONE}.before"
cmp -s "$TRANSACTION_TWO" "${TRANSACTION_TWO}.before"
test ! -e "$(<"$TRANSACTION_DIR_LOG")"

# A target changed outside the transaction is preserved and its verified
# original remains available for explicit recovery.
MISMATCH_TARGET="${TMP_ROOT}/transaction-mismatch.md"
MISMATCH_DIR_LOG="${TMP_ROOT}/mismatch-transaction-dir"
{
  printf '%s\n' "$AGENT_GUIDELINES_MARKER_BEGIN"
  printf 'original managed content\n'
  printf '%s\n' "$AGENT_GUIDELINES_MARKER_END"
} > "$MISMATCH_TARGET"
cp -a "$MISMATCH_TARGET" "${MISMATCH_TARGET}.before"
mismatch_status=0
(
  agent_guidelines_transaction_begin
  printf '%s\n' "$AGENT_GUIDELINES_TRANSACTION_DIR" > "$MISMATCH_DIR_LOG"
  agent_guidelines_update_managed_block \
    "$MISMATCH_TARGET" "$BLOCK_FILE" >/dev/null
  printf 'external concurrent content\n' > "$MISMATCH_TARGET"
  exit 28
) 2>"${TMP_ROOT}/mismatch.err" || mismatch_status=$?
test "$mismatch_status" -eq 1
grep -Fxq 'external concurrent content' "$MISMATCH_TARGET"
MISMATCH_RECOVERY="$(<"$MISMATCH_DIR_LOG")"
test -d "$MISMATCH_RECOVERY"
mapfile -t mismatch_entries < <(find "$MISMATCH_RECOVERY/entries" \
  -mindepth 1 -maxdepth 1 -type d -print)
test "${#mismatch_entries[@]}" -eq 1
cmp -s "${MISMATCH_TARGET}.before" "${mismatch_entries[0]}/original"
grep -Fq 'transaction rollback incomplete' "${TMP_ROOT}/mismatch.err"
rm -rf "$MISMATCH_RECOVERY"

printf 'managed-block safety tests passed\n'
