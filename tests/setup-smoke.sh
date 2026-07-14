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

GLOBAL_SKILLS=(
  agent-memory
  avr
  code-review
  debug
  dependency-audit
  docs-audit
  docs-review
  docstrings
  esp-idf
  explain
  firmware-review
  project-setup
  script-audit
  security-audit
  stm32
  test-audit
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
  local harness skill
  for harness in "${SKILL_HARNESSES[@]}"; do
    for skill in "${GLOBAL_SKILLS[@]}"; do
      test -L "${HOME}/${harness}/skills/${skill}"
    done
  done

  test -L "${HOME}/.agent-guidelines/rules"

  # Rules are delivered through the assembled context files only;
  # no per-rule symlinks may be installed.
  test ! -e "${HOME}/.claude/rules/agent-conduct.md"
  test ! -e "${HOME}/.claude/rules/git-workflow.md"

  for skill_dir in "${ROOT_DIR}"/skills/*/; do
    skill="$(basename "$skill_dir")"
    if [[ ! " ${GLOBAL_SKILLS[*]} " =~ [[:space:]]${skill}[[:space:]] ]]; then
      echo "canonical skill is not classified as global: $skill" >&2
      return 1
    fi
  done
}

assert_context_files() {
  local target
  for target in "${CONTEXT_TARGETS[@]}"; do
    local path="${HOME}/${target}"
    test -f "$path"
    grep -Fq "<!-- BEGIN agent-guidelines project rules -->" "$path"
    grep -Fq "<!-- END agent-guidelines project rules -->" "$path"
    grep -Eq "^## Agent Conduct Rules$" "$path"
    grep -Eq "^## Git Workflow Rules$" "$path"
    if grep -Eq "^# " "$path"; then
      echo "stray H1 in $path" >&2
      return 1
    fi
    if awk 'BEGIN{p=""} /^$/&&p==""{f=1;exit} {p=$0} END{exit !f}' "$path"; then
      echo "consecutive blank lines in $path" >&2
      return 1
    fi
    grep -Fq "## Situational Rules" "$path"
    grep -Fq "agent-guidelines/rules/code-quality.md" "$path"
    grep -Fq "agent-guidelines/rules/testing.md" "$path"
    grep -Fq "agent-guidelines/rules/merge-requests.md" "$path"
    if grep -Eq "^## Pull / Merge Request Rules$" "$path"; then
      echo "recall-tier rule inlined in $path" >&2
      return 1
    fi
    if grep -Fq "## Situational Skills" "$path"; then
      echo "globally installed skill leaked into router in $path" >&2
      return 1
    fi
    if grep -Fq "load: always" "$path"; then
      echo "frontmatter leaked into $path" >&2
      return 1
    fi
    if grep -Eq "^argument-hint:" "$path"; then
      echo "skill frontmatter leaked into $path" >&2
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

# No rule of any tier is linked globally; context files carry them.
test ! -e "${HOME}/.claude/rules/testing.md"
test ! -e "${HOME}/.claude/rules/code-quality.md"

"${ROOT_DIR}/setup.sh" --install --no-color > "$SECOND_OUT"
grep -Eq "created:[[:space:]]+0" "$SECOND_OUT"
grep -Eq "current:[[:space:]]+${expected_links}" "$SECOND_OUT"
grep -Eq "context current:[[:space:]]+4" "$SECOND_OUT"
assert_context_files

# Staleness detection: change a line inside one managed block, then
# verify --status flags the file, --dry-run previews exactly one
# update, and --install repairs it.
STALE_TARGET="${HOME}/.claude/CLAUDE.md"
STALE_STATUS_OUT="${TMP_ROOT}/stale-status.out"
STALE_DRY_OUT="${TMP_ROOT}/stale-dry.out"
STALE_REPAIR_OUT="${TMP_ROOT}/stale-repair.out"
awk '{ sub(/^## Agent Conduct Rules$/, "## Edited Rules"); print }' \
  "$STALE_TARGET" > "${STALE_TARGET}.tmp"
mv "${STALE_TARGET}.tmp" "$STALE_TARGET"

"${ROOT_DIR}/setup.sh" --status --no-color > "$STALE_STATUS_OUT"
grep -Eq "context current:[[:space:]]+3" "$STALE_STATUS_OUT"
grep -Eq "context stale:[[:space:]]+1" "$STALE_STATUS_OUT"
grep -Fq "out of date; run --install" "$STALE_STATUS_OUT"

"${ROOT_DIR}/setup.sh" --dry-run --no-color > "$STALE_DRY_OUT"
grep -Eq "context updated:[[:space:]]+1" "$STALE_DRY_OUT"
grep -Eq "context current:[[:space:]]+3" "$STALE_DRY_OUT"

"${ROOT_DIR}/setup.sh" --install --no-color > "$STALE_REPAIR_OUT"
grep -Eq "context updated:[[:space:]]+1" "$STALE_REPAIR_OUT"
grep -Eq "context current:[[:space:]]+3" "$STALE_REPAIR_OUT"
assert_context_files

"${ROOT_DIR}/setup.sh" --remove --no-color > "$REMOVE_OUT"
grep -Eq "removed:[[:space:]]+${expected_links}" "$REMOVE_OUT"
grep -Eq "context removed:[[:space:]]+4" "$REMOVE_OUT"
test ! -e "${HOME}/.claude/rules/git-workflow.md"
assert_no_residue

export HOME="$FORCE_REPO_HOME"
mkdir -p "${HOME}/.claude/skills"
printf 'local file\n' > "${HOME}/.claude/skills/code-review"

"${ROOT_DIR}/setup.sh" --force --backup-path "$CUSTOM_BACKUP_PATH" --no-color > "$FORCE_OUT"
grep -Eq "backups:[[:space:]]+1" "$FORCE_OUT"
grep -Eq "forced:[[:space:]]+true" "$FORCE_OUT"
grep -Eq "backup path:[[:space:]]+${CUSTOM_BACKUP_PATH}/run\." "$FORCE_OUT"
grep -Eq "warnings:[[:space:]]+0" "$FORCE_OUT"
test -L "${HOME}/.claude/skills/code-review"
backup_file="$(find "$CUSTOM_BACKUP_PATH" -path "*/.claude/skills/code-review" -type f -print -quit)"
test -n "$backup_file"

# --prune scenario: plant orphan symlinks pointing into this repository
# (two rule links of the kind earlier installs created, one obsolete skill
# link) and a foreign symlink whose target sits outside the
# repository. Verify that --prune --dry-run previews removal of the
# orphans only, --prune actually removes them, and the foreign symlink
# and managed links remain intact.
export HOME="${TMP_ROOT}/prune-home"
mkdir -p "$HOME"
PRUNE_DRY_OUT="${TMP_ROOT}/prune-dry.out"
PRUNE_OUT="${TMP_ROOT}/prune.out"
FOREIGN_DIR="${TMP_ROOT}/foreign"
FOREIGN_TARGET="${FOREIGN_DIR}/notes.md"

"${ROOT_DIR}/setup.sh" --install --no-color > /dev/null

mkdir -p "$FOREIGN_DIR" "${HOME}/.claude/rules"
printf 'user-private\n' > "$FOREIGN_TARGET"
ln -s "${ROOT_DIR}/rules/agent-conduct.md" "${HOME}/.claude/rules/agent-conduct.md"
ln -s "${ROOT_DIR}/rules/code-quality.md" "${HOME}/.claude/rules/code-quality.md"
ln -s "${ROOT_DIR}/skills/security-audit" "${HOME}/.claude/skills/obsolete-skill"
ln -s "$FOREIGN_TARGET" "${HOME}/.claude/rules/foreign.md"

"${ROOT_DIR}/setup.sh" --prune --dry-run --no-color > "$PRUNE_DRY_OUT"
grep -Eq "action:[[:space:]]+prune" "$PRUNE_DRY_OUT"
grep -Eq "pruned:[[:space:]]+3" "$PRUNE_DRY_OUT"
grep -Fq "agent-conduct.md" "$PRUNE_DRY_OUT"
grep -Fq "code-quality.md" "$PRUNE_DRY_OUT"
grep -Fq "obsolete-skill" "$PRUNE_DRY_OUT"
if grep -Fq "foreign.md" "$PRUNE_DRY_OUT"; then
  echo "foreign symlink reported by --prune --dry-run" >&2
  exit 1
fi
test -L "${HOME}/.claude/rules/agent-conduct.md"
test -L "${HOME}/.claude/rules/code-quality.md"
test -L "${HOME}/.claude/skills/obsolete-skill"
test -L "${HOME}/.claude/rules/foreign.md"

"${ROOT_DIR}/setup.sh" --prune --no-color > "$PRUNE_OUT"
grep -Eq "pruned:[[:space:]]+3" "$PRUNE_OUT"
test ! -e "${HOME}/.claude/rules/agent-conduct.md"
test ! -e "${HOME}/.claude/rules/code-quality.md"
test ! -e "${HOME}/.claude/skills/obsolete-skill"
test -L "${HOME}/.claude/rules/foreign.md"
test -L "${HOME}/.claude/skills/agent-memory"

"${ROOT_DIR}/setup.sh" --prune --no-color > "$PRUNE_OUT"
grep -Eq "pruned:[[:space:]]+0" "$PRUNE_OUT"
grep -Fq "no orphan links found" "$PRUNE_OUT"

printf 'setup smoke tests passed\n'
