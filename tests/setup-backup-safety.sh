#!/usr/bin/env bash
# Verifies forced replacements use unique, complete, verified backups.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-setup-backups.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

# shellcheck source=lib/safe-mutations.sh
. "${ROOT_DIR}/lib/safe-mutations.sh"

expect_fail() {
  if "$@" >"${TMP_ROOT}/unexpected.out" 2>"${TMP_ROOT}/expected.err"; then
    echo "expected command to fail: $*" >&2
    return 1
  fi
}

export HOME="${TMP_ROOT}/force-home"
BACKUP_PARENT="${TMP_ROOT}/backups"
CONFLICT="${HOME}/.claude/skills/code-review"
mkdir -p "${CONFLICT}/nested"
printf 'first payload\n' > "${CONFLICT}/nested/.hidden"
ln -s nested/.hidden "${CONFLICT}/payload-link"
chmod 750 "$CONFLICT"
cp -a "$CONFLICT" "${TMP_ROOT}/first-expected"

"${ROOT_DIR}/setup.sh" \
  --force --backup-path "$BACKUP_PARENT" --no-color >/dev/null
test -L "$CONFLICT"

# Replace the test-created managed link with a second conflict at the same
# path, then reuse the same backup parent.
rm "$CONFLICT"
printf 'second payload\n' > "$CONFLICT"
cp -a "$CONFLICT" "${TMP_ROOT}/second-expected"
"${ROOT_DIR}/setup.sh" \
  --force --backup-path "$BACKUP_PARENT" --no-color >/dev/null
test -L "$CONFLICT"

mapfile -t runs < <(find "$BACKUP_PARENT" -mindepth 1 -maxdepth 1 \
  -type d -name 'run.*' -print | sort)
test "${#runs[@]}" -eq 2
test "${runs[0]}" != "${runs[1]}"

mapfile -t saved_conflicts < <(find "$BACKUP_PARENT" \
  -path '*/.claude/skills/code-review' -print | sort)
test "${#saved_conflicts[@]}" -eq 2

first_backup=""
second_backup=""
for saved in "${saved_conflicts[@]}"; do
  if [ -d "$saved" ]; then
    first_backup="$saved"
  elif [ -f "$saved" ]; then
    second_backup="$saved"
  fi
done
test -n "$first_backup"
test -n "$second_backup"
agent_guidelines_verify_copy "${TMP_ROOT}/first-expected" "$first_backup"
agent_guidelines_verify_copy "${TMP_ROOT}/second-expected" "$second_backup"

# An invalid backup parent fails before any live setup target changes.
export HOME="${TMP_ROOT}/backup-failure-home"
FAILED_CONFLICT="${HOME}/.claude/skills/code-review"
mkdir -p "$(dirname "$FAILED_CONFLICT")"
printf 'must survive\n' > "$FAILED_CONFLICT"
BAD_BACKUP_PARENT="${TMP_ROOT}/not-a-directory"
printf 'blocking file\n' > "$BAD_BACKUP_PARENT"
cp -a "$HOME" "${HOME}.before"
expect_fail "${ROOT_DIR}/setup.sh" \
  --force --backup-path "$BAD_BACKUP_PARENT" --no-color
diff -qr "$HOME" "${HOME}.before" >/dev/null

# A conflict in the last planned link is detected before earlier links exist.
export HOME="${TMP_ROOT}/late-conflict-home"
LATE_CONFLICT="${HOME}/.codex/skills/test-audit"
mkdir -p "$(dirname "$LATE_CONFLICT")"
mkfifo "$LATE_CONFLICT"
expect_fail "${ROOT_DIR}/setup.sh" --force --no-color
test -p "$LATE_CONFLICT"
test ! -e "${HOME}/.agent-guidelines/rules"
test ! -e "${HOME}/.claude/skills/agent-memory"

# Dry-run reports a forced replacement without creating a backup or changing
# the conflict.
export HOME="${TMP_ROOT}/dry-run-home"
DRY_CONFLICT="${HOME}/.claude/skills/code-review"
DRY_BACKUPS="${TMP_ROOT}/dry-run-backups"
mkdir -p "$(dirname "$DRY_CONFLICT")"
printf 'dry payload\n' > "$DRY_CONFLICT"
cp -a "$HOME" "${HOME}.before"
"${ROOT_DIR}/setup.sh" --force --dry-run \
  --backup-path "$DRY_BACKUPS" --no-color >/dev/null
diff -qr "$HOME" "${HOME}.before" >/dev/null
test ! -e "$DRY_BACKUPS"

printf 'setup backup safety tests passed\n'
