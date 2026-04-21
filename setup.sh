#!/usr/bin/env bash
# Sets up local tool links for this agent-guidelines repository.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
RULES_DIR="${REPO_DIR}/rules"
SKILLS_DIR="${REPO_DIR}/skills"

ACTION="install"
DRY_RUN=false
FORCE=false
BACKUP_ROOT="${HOME}/.agent-guidelines/backups/$(date +%Y%m%d-%H%M%S)"

CREATED=0
CURRENT=0
REMOVED=0
BACKED_UP=0
SKIPPED=0
WARNINGS=0

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
  "rule|${HOME}/.claude/rules/changelog-versioned.md|${RULES_DIR}/changelog-versioned.md"
  "rule|${HOME}/.claude/rules/versioning-semver.md|${RULES_DIR}/versioning-semver.md"
  "rule|${HOME}/.claude/rules/backward-compatibility.md|${RULES_DIR}/backward-compatibility.md"
  "skill|${HOME}/.claude/skills/project-setup|${SKILLS_DIR}/project-setup"
  "skill|${HOME}/.agents/skills/project-setup|${SKILLS_DIR}/project-setup"
  "skill|${HOME}/.codex/skills/project-setup|${SKILLS_DIR}/project-setup"
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
  -h, --help      Show this help

Examples:
  ./setup.sh --status
  ./setup.sh --dry-run
  ./setup.sh --install
  ./setup.sh --force
  ./setup.sh --remove --dry-run
EOF
}

info() {
  printf '%s\n' "$*"
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

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path"
  elif command -v realpath >/dev/null 2>&1; then
    realpath -m "$path" 2>/dev/null || realpath "$path"
  elif readlink -f "$path" >/dev/null 2>&1; then
    readlink -f "$path"
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
  else
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path"
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

  backup_path="${BACKUP_ROOT}${link_path}"

  if [ "$DRY_RUN" = true ]; then
    info "  backup ${link_path} -> ${backup_path}"
    BACKED_UP=$((BACKED_UP + 1))
    return
  fi

  mkdir -p "$(dirname "$backup_path")"
  mv "$link_path" "$backup_path"
  info "  backup ${link_path} -> ${backup_path}"
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
      info "  current ${kind} ${link_path}"
      CURRENT=$((CURRENT + 1))
      ;;
    missing)
      if [ "$DRY_RUN" = true ]; then
        info "  create  ${kind} ${link_path} -> ${source}"
      else
        mkdir -p "$(dirname "$link_path")"
        ln -s "$source" "$link_path"
        info "  create  ${kind} ${link_path} -> ${source}"
      fi
      CREATED=$((CREATED + 1))
      ;;
    *)
      if [ "$FORCE" = true ]; then
        backup_conflict "$link_path"
        if [ "$DRY_RUN" = false ]; then
          mkdir -p "$(dirname "$link_path")"
          ln -s "$source" "$link_path"
        fi
        info "  replace ${kind} ${link_path} -> ${source}"
        CREATED=$((CREATED + 1))
      else
        warn "skip ${link_path} (${state}); use --force to back it up"
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
      info "  remove  ${kind} ${link_path}"
    else
      rm "$link_path"
      info "  remove  ${kind} ${link_path}"
    fi
    REMOVED=$((REMOVED + 1))
  else
    local state
    state="$(classify_path "$link_path" "$source")"
    info "  skip    ${kind} ${link_path} (${state})"
    SKIPPED=$((SKIPPED + 1))
  fi
}

status_link() {
  local kind="$1"
  local link_path="$2"
  local source="$3"
  local state

  state="$(classify_path "$link_path" "$source")"
  info "  ${state} ${kind} ${link_path} -> ${source}"
  case "$state" in
    current) CURRENT=$((CURRENT + 1)) ;;
    missing) SKIPPED=$((SKIPPED + 1)) ;;
    *) WARNINGS=$((WARNINGS + 1)) ;;
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
      info ""
      info "${kind}s"
    fi

    case "$ACTION" in
      install) install_link "$kind" "$link_path" "$source" ;;
      remove) remove_link "$kind" "$link_path" "$source" ;;
      status) status_link "$kind" "$link_path" "$source" ;;
    esac
  done
}

print_summary() {
  info ""
  info "Summary"
  info "  action: ${ACTION}"
  info "  dry-run: ${DRY_RUN}"
  info "  created: ${CREATED}"
  info "  current: ${CURRENT}"
  info "  removed: ${REMOVED}"
  info "  backed up: ${BACKED_UP}"
  info "  skipped: ${SKIPPED}"
  info "  warnings: ${WARNINGS}"
}

main() {
  parse_args "$@"
  validate_sources
  process_links
  print_summary
}

main "$@"
