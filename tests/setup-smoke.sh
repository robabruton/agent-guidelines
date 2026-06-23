#!/usr/bin/env bash
# Verifies the local tool setup command in a temporary HOME.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-tool-setup.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"

STATUS_OUT="${TMP_ROOT}/status.out"
DRY_RUN_OUT="${TMP_ROOT}/dry-run.out"
INSTALL_OUT="${TMP_ROOT}/install.out"
SECOND_OUT="${TMP_ROOT}/second.out"
REMOVE_OUT="${TMP_ROOT}/remove.out"
FORCE_REPO_HOME="${TMP_ROOT}/force-home"
FORCE_OUT="${TMP_ROOT}/force.out"
CUSTOM_BACKUP_PATH="${TMP_ROOT}/custom-backups"

"${ROOT_DIR}/setup.sh" --status --no-color > "$STATUS_OUT"
grep -Eq "action:[[:space:]]+status" "$STATUS_OUT"
grep -Eq "conflicts:[[:space:]]+0" "$STATUS_OUT"
expected_links="$(sed -nE 's/^[[:space:]]*missing:[[:space:]]+([0-9]+)$/\1/p' "$STATUS_OUT")"
test -n "$expected_links"
test "$expected_links" -gt 0

"${ROOT_DIR}/setup.sh" --dry-run --no-color > "$DRY_RUN_OUT"
grep -Eq "action:[[:space:]]+install" "$DRY_RUN_OUT"
grep -Eq "dry run:[[:space:]]+true" "$DRY_RUN_OUT"
grep -Eq "forced:[[:space:]]+false" "$DRY_RUN_OUT"
test ! -e "${HOME}/.claude/rules/git-workflow.md"

"${ROOT_DIR}/setup.sh" --install --no-color > "$INSTALL_OUT"
grep -Eq "created:[[:space:]]+${expected_links}" "$INSTALL_OUT"
test -L "${HOME}/.claude/rules/git-workflow.md"
test -L "${HOME}/.claude/rules/git-messages.md"
test -L "${HOME}/.claude/skills/project-setup"
test -L "${HOME}/.claude/skills/code-review"
test -L "${HOME}/.claude/skills/dependency-audit"
test -L "${HOME}/.claude/skills/docstrings"
test -L "${HOME}/.claude/skills/docs-audit"
test -L "${HOME}/.claude/skills/docs-review"
test -L "${HOME}/.claude/skills/explain"
test -L "${HOME}/.claude/skills/firmware-review"
test -L "${HOME}/.claude/skills/script-audit"
test -L "${HOME}/.claude/skills/security-audit"
test -L "${HOME}/.claude/skills/test-audit"
test -L "${HOME}/.claude/skills/agent-memory"
test -L "${HOME}/.agents/skills/project-setup"
test -L "${HOME}/.agents/skills/code-review"
test -L "${HOME}/.agents/skills/dependency-audit"
test -L "${HOME}/.agents/skills/docstrings"
test -L "${HOME}/.agents/skills/docs-audit"
test -L "${HOME}/.agents/skills/docs-review"
test -L "${HOME}/.agents/skills/explain"
test -L "${HOME}/.agents/skills/firmware-review"
test -L "${HOME}/.agents/skills/script-audit"
test -L "${HOME}/.agents/skills/security-audit"
test -L "${HOME}/.agents/skills/test-audit"
test -L "${HOME}/.agents/skills/agent-memory"
test -L "${HOME}/.codex/skills/project-setup"
test -L "${HOME}/.codex/skills/code-review"
test -L "${HOME}/.codex/skills/dependency-audit"
test -L "${HOME}/.codex/skills/docstrings"
test -L "${HOME}/.codex/skills/docs-audit"
test -L "${HOME}/.codex/skills/docs-review"
test -L "${HOME}/.codex/skills/explain"
test -L "${HOME}/.codex/skills/firmware-review"
test -L "${HOME}/.codex/skills/script-audit"
test -L "${HOME}/.codex/skills/security-audit"
test -L "${HOME}/.codex/skills/test-audit"
test -L "${HOME}/.codex/skills/agent-memory"

"${ROOT_DIR}/setup.sh" --install --no-color > "$SECOND_OUT"
grep -Eq "created:[[:space:]]+0" "$SECOND_OUT"
grep -Eq "current:[[:space:]]+${expected_links}" "$SECOND_OUT"

"${ROOT_DIR}/setup.sh" --remove --no-color > "$REMOVE_OUT"
grep -Eq "removed:[[:space:]]+${expected_links}" "$REMOVE_OUT"
test ! -e "${HOME}/.claude/rules/git-workflow.md"

export HOME="$FORCE_REPO_HOME"
mkdir -p "${HOME}/.claude/rules"
printf 'local file\n' > "${HOME}/.claude/rules/git-workflow.md"

"${ROOT_DIR}/setup.sh" --force --backup-path "$CUSTOM_BACKUP_PATH" --no-color > "$FORCE_OUT"
grep -Eq "backups:[[:space:]]+1" "$FORCE_OUT"
grep -Eq "forced:[[:space:]]+true" "$FORCE_OUT"
grep -Eq "backup path:[[:space:]]+${CUSTOM_BACKUP_PATH}" "$FORCE_OUT"
grep -Eq "warnings:[[:space:]]+0" "$FORCE_OUT"
test -L "${HOME}/.claude/rules/git-workflow.md"
backup_file="$(find "$CUSTOM_BACKUP_PATH" -path "*/.claude/rules/git-workflow.md" -type f -print -quit)"
test -n "$backup_file"

printf 'setup smoke tests passed\n'
