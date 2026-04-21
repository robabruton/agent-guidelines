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

"${ROOT_DIR}/setup.sh" --status > "$STATUS_OUT"
grep -Fq "action: status" "$STATUS_OUT"
grep -Fq "skipped: 16" "$STATUS_OUT"

"${ROOT_DIR}/setup.sh" --dry-run > "$DRY_RUN_OUT"
grep -Fq "action: install" "$DRY_RUN_OUT"
grep -Fq "dry-run: true" "$DRY_RUN_OUT"
test ! -e "${HOME}/.claude/rules/git-workflow.md"

"${ROOT_DIR}/setup.sh" --install > "$INSTALL_OUT"
grep -Fq "created: 16" "$INSTALL_OUT"
test -L "${HOME}/.claude/rules/git-workflow.md"
test -L "${HOME}/.claude/skills/project-setup"
test -L "${HOME}/.agents/skills/project-setup"
test -L "${HOME}/.codex/skills/project-setup"

"${ROOT_DIR}/setup.sh" --install > "$SECOND_OUT"
grep -Fq "created: 0" "$SECOND_OUT"
grep -Fq "current: 16" "$SECOND_OUT"

"${ROOT_DIR}/setup.sh" --remove > "$REMOVE_OUT"
grep -Fq "removed: 16" "$REMOVE_OUT"
test ! -e "${HOME}/.claude/rules/git-workflow.md"

printf 'setup smoke tests passed\n'
