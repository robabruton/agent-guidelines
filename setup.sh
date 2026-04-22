#!/usr/bin/env bash
# Sets up local tool links for this agent-guidelines repository.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
RULES_DIR="${REPO_DIR}/rules"
SKILLS_DIR="${REPO_DIR}/skills"

ACTION="install"
DRY_RUN=false
FORCE=false
COLOR_MODE="auto"
BACKUP_PATH="${HOME}/.agent-guidelines/backups/$(date +%Y%m%d-%H%M%S)"

CREATED=0
CURRENT=0
REMOVED=0
BACKED_UP=0
SKIPPED=0
WARNINGS=0
MISSING=0
CONFLICTS=0

LINKS=(
  "rule|${HOME}/.claude/rules/git-workflow.md|${RULES_DIR}/git-workflow.md"
  "rule|${HOME}/.claude/rules/development-attribution.md|${RULES_DIR}/development-attribution.md"
  "rule|${HOME}/.claude/rules/configuration.md|${RULES_DIR}/configuration.md"
  "rule|${HOME}/.claude/rules/testing.md|${RULES_DIR}/testing.md"
  "rule|${HOME}/.claude/rules/documentation.md|${RULES_DIR}/documentation.md"
  "rule|${HOME}/.claude/rules/docstrings.md|${RULES_DIR}/docstrings.md"
  "rule|${HOME}/.claude/rules/scripts.md|${RULES_DIR}/scripts.md"
  "rule|${HOME}/.claude/rules/dependencies.md|${RULES_DIR}/dependencies.md"
  "rule|${HOME}/.claude/rules/changelog-common.md|${RULES_DIR}/changelog-common.md"
  "rule|${HOME}/.claude/rules/changelog-date.md|${RULES_DIR}/changelog-date.md"
  "rule|${HOME}/.claude/rules/changelog-version.md|${RULES_DIR}/changelog-version.md"
  "rule|${HOME}/.claude/rules/versioning-semver.md|${RULES_DIR}/versioning-semver.md"
  "rule|${HOME}/.claude/rules/backward-compatibility.md|${RULES_DIR}/backward-compatibility.md"
  "skill|${HOME}/.claude/skills/project-setup|${SKILLS_DIR}/project-setup"
  "skill|${HOME}/.claude/skills/docstrings|${SKILLS_DIR}/docstrings"
  "skill|${HOME}/.claude/skills/docs-audit|${SKILLS_DIR}/docs-audit"
  "skill|${HOME}/.claude/skills/docs-review|${SKILLS_DIR}/docs-review"
  "skill|${HOME}/.claude/skills/firmware-review|${SKILLS_DIR}/firmware-review"
  "skill|${HOME}/.claude/skills/script-audit|${SKILLS_DIR}/script-audit"
  "skill|${HOME}/.claude/skills/security-audit|${SKILLS_DIR}/security-audit"
  "skill|${HOME}/.claude/skills/test-audit|${SKILLS_DIR}/test-audit"
  "skill|${HOME}/.agents/skills/project-setup|${SKILLS_DIR}/project-setup"
  "skill|${HOME}/.agents/skills/docstrings|${SKILLS_DIR}/docstrings"
  "skill|${HOME}/.agents/skills/docs-audit|${SKILLS_DIR}/docs-audit"
  "skill|${HOME}/.agents/skills/docs-review|${SKILLS_DIR}/docs-review"
  "skill|${HOME}/.agents/skills/firmware-review|${SKILLS_DIR}/firmware-review"
  "skill|${HOME}/.agents/skills/script-audit|${SKILLS_DIR}/script-audit"
  "skill|${HOME}/.agents/skills/security-audit|${SKILLS_DIR}/security-audit"
  "skill|${HOME}/.agents/skills/test-audit|${SKILLS_DIR}/test-audit"
  "skill|${HOME}/.codex/skills/project-setup|${SKILLS_DIR}/project-setup"
  "skill|${HOME}/.codex/skills/docstrings|${SKILLS_DIR}/docstrings"
  "skill|${HOME}/.codex/skills/docs-audit|${SKILLS_DIR}/docs-audit"
  "skill|${HOME}/.codex/skills/docs-review|${SKILLS_DIR}/docs-review"
  "skill|${HOME}/.codex/skills/firmware-review|${SKILLS_DIR}/firmware-review"
  "skill|${HOME}/.codex/skills/script-audit|${SKILLS_DIR}/script-audit"
  "skill|${HOME}/.codex/skills/security-audit|${SKILLS_DIR}/security-audit"
  "skill|${HOME}/.codex/skills/test-audit|${SKILLS_DIR}/test-audit"
)

usage() {
  cat <<'EOF'
Usage: ./setup.sh [options]

Options:
  --install       Create or repair managed tool links (default)
  --remove        Remove managed links that point into this repository
  --status        Report link state without changing files
  --dry-run       Preview install or remove actions without changing files
  --force         Back up conflicting files before replacing them
  --backup-path   Path for forced replacement backups
  --no-color      Disable colored output
  -h, --help      Show this help

Examples:
  ./setup.sh --status
  ./setup.sh --dry-run
  ./setup.sh --install
  ./setup.sh --force --backup-path /tmp/agent-guidelines-backups
  ./setup.sh --remove --dry-run
EOF
}

info() {
  printf '%s\n' "$*"
}

setup_colors() {
  if [ "$COLOR_MODE" = "never" ] || [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    BLUE=""
    GREEN=""
    YELLOW=""
    RED=""
    CYAN=""
    DIM=""
    RESET=""
  else
    BLUE="$(printf '\033[1;34m')"
    GREEN="$(printf '\033[0;32m')"
    YELLOW="$(printf '\033[0;33m')"
    RED="$(printf '\033[0;31m')"
    CYAN="$(printf '\033[0;36m')"
    DIM="$(printf '\033[0;90m')"
    RESET="$(printf '\033[0m')"
  fi
}

section() {
  printf '\n%s%s%s\n' "$BLUE" "$1" "$RESET"
}

entry() {
  local color="$1"
  local mark="$2"
  local status="$3"
  local path="$4"
  local detail="${5:-}"

  if [ -n "$detail" ]; then
    printf '  %s%s %-14s%s%s  %s%s%s\n' \
      "$color" "$mark" "$status" "$RESET" "$path" "$DIM" "$detail" "$RESET"
  else
    printf '  %s%s %-14s%s%s\n' "$color" "$mark" "$status" "$RESET" "$path"
  fi
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install)
        ACTION="install"
        shift
        ;;
      --remove)
        ACTION="remove"
        shift
        ;;
      --status)
        ACTION="status"
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --backup-path)
        [ "$#" -gt 1 ] || die "--backup-path requires a path"
        BACKUP_PATH="$2"
        shift 2
        ;;
      --backup-path=*)
        BACKUP_PATH="${1#*=}"
        [ -n "$BACKUP_PATH" ] || die "--backup-path requires a path"
        shift
        ;;
      --no-color)
        COLOR_MODE="never"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done
}

real_path() {
  local path="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$path" 2>/dev/null || realpath "$path"
  elif command -v readlink >/dev/null 2>&1 && readlink -f "$path" >/dev/null 2>&1; then
    readlink -f "$path"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path"
  else
    printf '%s\n' "$path"
  fi
}

link_target() {
  local link_path="$1"
  local target

  target="$(readlink "$link_path")"
  case "$target" in
    /*) real_path "$target" ;;
    *) real_path "$(dirname "$link_path")/$target" ;;
  esac
}

source_path() {
  local path="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
  elif command -v readlink >/dev/null 2>&1 && readlink -f "$path" >/dev/null 2>&1; then
    readlink -f "$path"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path"
  else
    local dir
    local base
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
  fi
}

target_matches() {
  local link_path="$1"
  local expected="$2"

  [ -L "$link_path" ] || return 1
  [ "$(link_target "$link_path")" = "$(source_path "$expected")" ]
}

classify_path() {
  local link_path="$1"
  local expected="$2"

  if target_matches "$link_path" "$expected"; then
    printf 'current'
  elif [ -L "$link_path" ]; then
    if [ -e "$link_path" ]; then
      printf 'foreign-symlink'
    else
      printf 'broken-symlink'
    fi
  elif [ -f "$link_path" ]; then
    printf 'file'
  elif [ -d "$link_path" ]; then
    printf 'directory'
  elif [ -e "$link_path" ]; then
    printf 'other'
  else
    printf 'missing'
  fi
}

validate_sources() {
  local ok=true
  local entry

  for entry in "${LINKS[@]}"; do
    local source="${entry##*|}"
    if [ ! -e "$source" ]; then
      warn "missing source: $source"
      ok=false
    fi
  done

  [ "$ok" = true ] || die "source validation failed"
}

backup_conflict() {
  local link_path="$1"
  local backup_path

  backup_path="${BACKUP_PATH}${link_path}"

  if [ "$DRY_RUN" = true ]; then
    entry "$CYAN" "?" "would back up" "$link_path" "to backup directory"
    BACKED_UP=$((BACKED_UP + 1))
    return
  fi

  mkdir -p "$(dirname "$backup_path")"
  mv "$link_path" "$backup_path"
  entry "$CYAN" "↳" "backed up" "$link_path" "-> $backup_path"
  BACKED_UP=$((BACKED_UP + 1))
}

install_link() {
  local kind="$1"
  local link_path="$2"
  local source="$3"
  local state

  state="$(classify_path "$link_path" "$source")"
  case "$state" in
    current)
      entry "$GREEN" "✓" "current" "$link_path" "already correct"
      CURRENT=$((CURRENT + 1))
      ;;
    missing)
      if [ "$DRY_RUN" = true ]; then
        entry "$CYAN" "?" "would create" "$link_path" "-> $source"
      else
        mkdir -p "$(dirname "$link_path")"
        ln -s "$source" "$link_path"
        entry "$GREEN" "+" "created" "$link_path" "-> $source"
      fi
      CREATED=$((CREATED + 1))
      ;;
    *)
      if [ "$FORCE" = true ]; then
        backup_conflict "$link_path"
        if [ "$DRY_RUN" = false ]; then
          mkdir -p "$(dirname "$link_path")"
          ln -s "$source" "$link_path"
          entry "$GREEN" "↻" "replaced" "$link_path" "-> $source"
        else
          entry "$CYAN" "?" "would replace" "$link_path" "with $source"
        fi
        CREATED=$((CREATED + 1))
      else
        entry "$YELLOW" "!" "skipped" "$link_path" "$state conflict; use --force"
        WARNINGS=$((WARNINGS + 1))
        SKIPPED=$((SKIPPED + 1))
      fi
      ;;
  esac
}

remove_link() {
  local kind="$1"
  local link_path="$2"
  local source="$3"

  if target_matches "$link_path" "$source"; then
    if [ "$DRY_RUN" = true ]; then
      entry "$CYAN" "?" "would remove" "$link_path" "managed link"
    else
      rm "$link_path"
      entry "$RED" "-" "removed" "$link_path" "managed link removed"
    fi
    REMOVED=$((REMOVED + 1))
  else
    local state
    state="$(classify_path "$link_path" "$source")"
    entry "$DIM" "·" "skipped" "$link_path" "$state; not managed by setup.sh"
    SKIPPED=$((SKIPPED + 1))
  fi
}

status_link() {
  local kind="$1"
  local link_path="$2"
  local source="$3"
  local state

  state="$(classify_path "$link_path" "$source")"
  case "$state" in
    current)
      entry "$GREEN" "✓" "current" "$link_path" "linked to expected source"
      CURRENT=$((CURRENT + 1))
      ;;
    missing)
      entry "$DIM" "·" "missing" "$link_path" "will be created by install"
      MISSING=$((MISSING + 1))
      SKIPPED=$((SKIPPED + 1))
      ;;
    *)
      entry "$YELLOW" "!" "$state" "$link_path" "conflict; use --force"
      CONFLICTS=$((CONFLICTS + 1))
      WARNINGS=$((WARNINGS + 1))
      ;;
  esac
}

process_links() {
  local current_kind=""
  local entry

  for entry in "${LINKS[@]}"; do
    local kind="${entry%%|*}"
    local rest="${entry#*|}"
    local link_path="${rest%%|*}"
    local source="${rest##*|}"

    if [ "$kind" != "$current_kind" ]; then
      current_kind="$kind"
      case "$kind" in
        rule) section "Rules" ;;
        skill) section "Skills" ;;
      esac
    fi

    case "$ACTION" in
      install) install_link "$kind" "$link_path" "$source" ;;
      remove) remove_link "$kind" "$link_path" "$source" ;;
      status) status_link "$kind" "$link_path" "$source" ;;
    esac
  done
}

print_summary() {
  section "Summary"
  printf '  %-10s %s\n' "action:" "$ACTION"

  case "$ACTION" in
    status)
      printf '  %-10s %s\n' "current:" "$CURRENT"
      printf '  %-10s %s\n' "missing:" "$MISSING"
      printf '  %-10s %s\n' "conflicts:" "$CONFLICTS"
      ;;
    install)
      printf '  %-10s %s\n' "dry run:" "$DRY_RUN"
      printf '  %-10s %s\n' "forced:" "$FORCE"
      printf '  %-10s %s\n' "backup path:" "$BACKUP_PATH"
      printf '  %-10s %s\n' "created:" "$CREATED"
      printf '  %-10s %s\n' "current:" "$CURRENT"
      printf '  %-10s %s\n' "backups:" "$BACKED_UP"
      printf '  %-10s %s\n' "skipped:" "$SKIPPED"
      printf '  %-10s %s\n' "warnings:" "$WARNINGS"
      ;;
    remove)
      printf '  %-10s %s\n' "dry run:" "$DRY_RUN"
      printf '  %-10s %s\n' "removed:" "$REMOVED"
      printf '  %-10s %s\n' "skipped:" "$SKIPPED"
      ;;
  esac

  printf '\n'
}

main() {
  parse_args "$@"
  setup_colors
  validate_sources
  process_links
  print_summary
}

main "$@"
