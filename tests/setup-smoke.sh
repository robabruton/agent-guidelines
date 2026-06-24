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

GLOBAL_RULES=(
  agent-conduct
  development-attribution
  git-workflow
  git-messages
  no-plans-on-main
  merge-requests
)

GLOBAL_SKILLS=(
  agent-memory
  code-review
  explain
  project-setup
)

SKILL_HARNESSES=(
  .claude
  .agents
  .codex
)

CONTEXT_TARGETS=(
  ".claude/CLAUDE.md"
  ".config/opencode/AGENTS.md"
  ".pi/agent/AGENTS.md"
  ".codex/AGENTS.md"
)

assert_managed_links() {
  local rule
  for rule in "${GLOBAL_RULES[@]}"; do
    test -L "${HOME}/.claude/rules/${rule}.md"
  done

  local harness skill
  for harness in "${SKILL_HARNESSES[@]}"; do
    for skill in "${GLOBAL_SKILLS[@]}"; do
      test -L "${HOME}/${harness}/skills/${skill}"
    done
  done

  test -L "${HOME}/.agent-guidelines/rules"
}

assert_context_files() {
  local target
  for target in "${CONTEXT_TARGETS[@]}"; do
    local path="${HOME}/${target}"
    test -f "$path"
    grep -Fq "<!-- BEGIN agent-guidelines project rules -->" "$path"
    grep -Fq "<!-- END agent-guidelines project rules -->" "$path"
    grep -Fq "# Agent Conduct Rules" "$path"
    grep -Fq "# Git Workflow Rules" "$path"
    grep -Fq "## Situational Rules" "$path"
    grep -Fq "agent-guidelines/rules/code-quality.md" "$path"
    grep -Fq "agent-guidelines/rules/testing.md" "$path"
    if grep -Fq "load: always" "$path"; then
      echo "frontmatter leaked into $path" >&2
      return 1
    fi
  done
}

assert_no_residue() {
  local target
  for target in "${CONTEXT_TARGETS[@]}"; do
    test ! -e "${HOME}/${target}"
  done
  test ! -e "${HOME}/.agent-guidelines/rules"
}

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
grep -Eq "context created:[[:space:]]+4" "$INSTALL_OUT"
assert_managed_links
assert_context_files

# A skill that is no longer global (e.g. test-audit) must NOT be linked
# globally by setup.sh after the global-set curation.
test ! -e "${HOME}/.claude/skills/test-audit"
test ! -e "${HOME}/.agents/skills/firmware-review"

# A rule that is load: recall must NOT be linked globally either.
test ! -e "${HOME}/.claude/rules/testing.md"
test ! -e "${HOME}/.claude/rules/code-quality.md"

"${ROOT_DIR}/setup.sh" --install --no-color > "$SECOND_OUT"
grep -Eq "created:[[:space:]]+0" "$SECOND_OUT"
grep -Eq "current:[[:space:]]+${expected_links}" "$SECOND_OUT"
grep -Eq "context current:[[:space:]]+4" "$SECOND_OUT"
assert_context_files

"${ROOT_DIR}/setup.sh" --remove --no-color > "$REMOVE_OUT"
grep -Eq "removed:[[:space:]]+${expected_links}" "$REMOVE_OUT"
grep -Eq "context removed:[[:space:]]+4" "$REMOVE_OUT"
test ! -e "${HOME}/.claude/rules/git-workflow.md"
assert_no_residue

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
