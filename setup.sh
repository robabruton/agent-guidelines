#!/usr/bin/env bash
# Sets up local tool links for this agent-guidelines repository.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
RULES_DIR="${REPO_DIR}/rules"
SKILLS_DIR="${REPO_DIR}/skills"

# shellcheck source=lib/assemble-rules.sh
. "${REPO_DIR}/lib/assemble-rules.sh"
# shellcheck source=lib/safe-mutations.sh
. "${REPO_DIR}/lib/safe-mutations.sh"

# Skills installed into every harness's global skills directory. Skills use
# the standard SKILL.md frontmatter schema, so the global set stays
# hardcoded here rather than deriving from a non-standard field.
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

# Harness directories that receive symlinks for every entry in
# GLOBAL_SKILLS. Adding a new harness adds one path here.
SKILL_HARNESSES=(
  "${HOME}/.claude/skills"
  "${HOME}/.agents/skills"
  "${HOME}/.codex/skills"
)

ACTION="install"
DRY_RUN=false
FORCE=false
COLOR_MODE="auto"
BACKUP_PATH="${HOME}/.agent-guidelines/backups"
BACKUP_RUN_DIR=""
LAST_BACKUP_PATH=""

# Stable on-disk path that recall-tier rule references in the global
# AGENTS.md router resolve to. Created as a directory symlink so all
# rule files are reachable from a single fixed path no matter where this
# repository is checked out.
RULE_STORE_PATH="${HOME}/.agent-guidelines/rules"

# Global context files that receive an inlined copy of the always-loaded
# rules plus a router section listing the recall-tier rules. Each entry
# is "path|label" where label is shown in the install/remove summary.
# Both OpenCode and Pi read AGENTS.md from these paths.
CONTEXT_TARGETS=(
  "${HOME}/.claude/CLAUDE.md|Claude Code global CLAUDE.md"
  "${HOME}/.config/opencode/AGENTS.md|OpenCode global AGENTS.md"
  "${HOME}/.pi/agent/AGENTS.md|Pi global AGENTS.md"
  "${HOME}/.codex/AGENTS.md|Codex global AGENTS.md"
)

CREATED=0
CURRENT=0
REMOVED=0
BACKED_UP=0
SKIPPED=0
WARNINGS=0
MISSING=0
CONFLICTS=0
PRUNED=0
CONTEXT_CREATED=0
CONTEXT_UPDATED=0
CONTEXT_UNCHANGED=0
CONTEXT_STALE=0
CONTEXT_REMOVED=0
CONTEXT_CLEARED=0
CONTEXT_ABSENT=0
CONTEXT_MISSING=0

LINKS=()

# Populate LINKS from the rule store and the hardcoded GLOBAL_SKILLS
# list, building skill entries for every harness directory in
# SKILL_HARNESSES. Rules reach every harness through the assembled
# context files only; installing them as per-rule symlinks as well
# would make harnesses that read a global rules directory load the
# same text twice.
build_links() {
  LINKS=()

  LINKS+=("store|${RULE_STORE_PATH}|${RULES_DIR}")

  local skill harness
  for harness in "${SKILL_HARNESSES[@]}"; do
    for skill in "${GLOBAL_SKILLS[@]}"; do
      LINKS+=("skill|${harness}/${skill}|${SKILLS_DIR}/${skill}")
    done
  done
}

usage() {
  cat <<'EOF'
Usage: ./setup.sh [options]

Options:
  --install       Create or repair managed tool links (default)
  --remove        Remove managed links that point into this repository
  --status        Report link state without changing files
  --prune         Report unowned symlinks in managed directories that point
                  into this repository but are outside the managed set
  --dry-run       Preview install, remove, or prune actions without
                  changing files
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
  ./setup.sh --prune --dry-run
  ./setup.sh --prune
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
      --prune)
        ACTION="prune"
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

backup_destination() {
  local link_path="$1"

  printf '%s%s\n' "$BACKUP_RUN_DIR" "$link_path"
}

prepare_forced_backups() {
  local entry rest link_path source state destination
  local conflict_count=0

  for entry in "${LINKS[@]}"; do
    rest="${entry#*|}"
    link_path="${rest%%|*}"
    source="${rest##*|}"
    state="$(classify_path "$link_path" "$source")"
    if [ "$state" != current ] && [ "$state" != missing ]; then
      conflict_count=$((conflict_count + 1))
    fi
  done

  [ "$conflict_count" -gt 0 ] || return 0

  if [ -L "$BACKUP_PATH" ] ||
    { [ -e "$BACKUP_PATH" ] && [ ! -d "$BACKUP_PATH" ]; }; then
    die "backup parent is not a regular directory: $BACKUP_PATH"
  fi
  [ "$DRY_RUN" = true ] && return 0

  BACKUP_RUN_DIR="$(agent_guidelines_create_backup_run "$BACKUP_PATH")" ||
    die "could not allocate a unique backup directory under $BACKUP_PATH"

  for entry in "${LINKS[@]}"; do
    rest="${entry#*|}"
    link_path="${rest%%|*}"
    source="${rest##*|}"
    state="$(classify_path "$link_path" "$source")"
    if [ "$state" = current ] || [ "$state" = missing ]; then
      continue
    fi

    destination="$(backup_destination "$link_path")"
    agent_guidelines_backup_object "$link_path" "$destination" ||
      die "backup verification failed for $link_path; live target unchanged"
  done
}

preflight_links() {
  local entry rest link_path source state path_type

  for entry in "${LINKS[@]}"; do
    rest="${entry#*|}"
    link_path="${rest%%|*}"
    source="${rest##*|}"
    agent_guidelines_assert_path_beneath \
      "$link_path" "$HOME" "managed link" || exit 1

    state="$(classify_path "$link_path" "$source")"
    if [ "$FORCE" = true ] && [ "$state" != current ] &&
      [ "$state" != missing ]; then
      path_type="$(agent_guidelines_path_type "$link_path")"
      case "$path_type" in
        regular|directory|symlink) ;;
        *) die "unsupported forced-replacement target: $link_path ($path_type)" ;;
      esac
    fi
  done

  if [ "$ACTION" = install ] && [ "$FORCE" = true ]; then
    prepare_forced_backups
  fi
}

backup_conflict() {
  local link_path="$1"
  local backup_path path_type

  backup_path="$(backup_destination "$link_path")"

  if [ "$DRY_RUN" = true ]; then
    entry "$CYAN" "?" "would back up" "$link_path" "to backup directory"
    BACKED_UP=$((BACKED_UP + 1))
    return
  fi

  [ -n "$BACKUP_RUN_DIR" ] || die "forced backup plan was not prepared"
  agent_guidelines_verify_copy "$link_path" "$backup_path" ||
    die "live target changed after backup planning: $link_path"

  path_type="$(agent_guidelines_path_type "$link_path")"
  case "$path_type" in
    directory) rm -rf "$link_path" ;;
    regular|symlink) rm -f "$link_path" ;;
    *) die "refusing to remove unsupported conflict: $link_path" ;;
  esac
  LAST_BACKUP_PATH="$backup_path"
  entry "$CYAN" "↳" "backed up" "$link_path" "-> $backup_path"
  BACKED_UP=$((BACKED_UP + 1))
}

install_link() {
  local kind="$1"
  local link_path="$2"
  local source="$3"
  local state
  local transaction_entry=""

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
        agent_guidelines_make_directory_safely "$(dirname "$link_path")" ||
          die "could not create link directory: $link_path"
        transaction_entry="$(agent_guidelines_transaction_allocate_entry \
          "$link_path" symlink "$source")" ||
          die "could not protect link creation: $link_path"
        if ! ln -s "$source" "$link_path"; then
          agent_guidelines_transaction_cancel_entry "$transaction_entry" ||
            die "link creation failed; recovery copy: $transaction_entry"
          die "link creation failed: $link_path"
        fi
        if ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
          agent_guidelines_transaction_cancel_entry "$transaction_entry" ||
            die "link verification failed; recovery copy: $transaction_entry"
          die "link verification failed: $link_path"
        fi
        entry "$GREEN" "+" "created" "$link_path" "-> $source"
      fi
      CREATED=$((CREATED + 1))
      ;;
    *)
      if [ "$FORCE" = true ]; then
        if [ "$DRY_RUN" = false ]; then
          transaction_entry="$(agent_guidelines_transaction_allocate_entry \
            "$link_path" symlink "$source")" ||
            die "could not protect forced replacement: $link_path"
        fi
        backup_conflict "$link_path"
        if [ "$DRY_RUN" = false ]; then
          if ! agent_guidelines_make_directory_safely "$(dirname "$link_path")" ||
            ! ln -s "$source" "$link_path"; then
            agent_guidelines_restore_object \
              "$LAST_BACKUP_PATH" "$link_path" ||
              die "link creation failed and restore failed; backup: $LAST_BACKUP_PATH"
            agent_guidelines_transaction_cancel_entry "$transaction_entry" ||
              die "link creation failed; recovery copy: $transaction_entry"
            die "link creation failed; restored original $link_path"
          fi
          if ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
            agent_guidelines_transaction_cancel_entry "$transaction_entry" ||
              die "link verification failed; recovery copy: $transaction_entry"
            die "link verification failed: $link_path"
          fi
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
  local transaction_entry=""

  if target_matches "$link_path" "$source"; then
    if [ "$DRY_RUN" = true ]; then
      entry "$CYAN" "?" "would remove" "$link_path" "managed link"
    else
      transaction_entry="$(agent_guidelines_transaction_allocate_entry \
        "$link_path" missing)" || die "could not protect link removal: $link_path"
      if ! rm "$link_path"; then
        agent_guidelines_transaction_cancel_entry "$transaction_entry" ||
          die "link removal failed; recovery copy: $transaction_entry"
        die "link removal failed: $link_path"
      fi
      if ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
        agent_guidelines_transaction_cancel_entry "$transaction_entry" ||
          die "link removal verification failed; recovery copy: $transaction_entry"
        die "link removal verification failed: $link_path"
      fi
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
        skill) section "Skills" ;;
        store) section "Stores" ;;
      esac
    fi

    case "$ACTION" in
      install) install_link "$kind" "$link_path" "$source" ;;
      remove) remove_link "$kind" "$link_path" "$source" ;;
      status) status_link "$kind" "$link_path" "$source" ;;
    esac
  done
}

preflight_context_targets() {
  local item path

  for item in "${CONTEXT_TARGETS[@]}"; do
    path="${item%%|*}"
    agent_guidelines_validate_managed_block_file "$path" || return 1
  done
}

assemble_context_block() {
  local block_file="$1"
  local always_rules=()
  local recall_rules=()
  local file load name

  for file in "${RULES_DIR}"/*.md; do
    [ -f "$file" ] || continue
    load="$(agent_guidelines_read_frontmatter_field "$file" load)"
    name="$(basename "$file" .md)"
    case "$load" in
      always) always_rules+=("$name") ;;
      recall) recall_rules+=("$name") ;;
    esac
  done

  local recall_skills=()
  local skill_dir skill_name g is_global
  for skill_dir in "${SKILLS_DIR}"/*/; do
    [ -f "${skill_dir}SKILL.md" ] || continue
    skill_name="$(basename "$skill_dir")"
    is_global=false
    for g in "${GLOBAL_SKILLS[@]}"; do
      if [ "$g" = "$skill_name" ]; then
        is_global=true
        break
      fi
    done
    [ "$is_global" = false ] && recall_skills+=("$skill_name")
  done

  {
    printf '%s\n\n' "$AGENT_GUIDELINES_MARKER_BEGIN"

    local r
    for r in "${always_rules[@]}"; do
      agent_guidelines_format_rule_body "${RULES_DIR}/${r}.md"
      printf '\n'
    done

    if [ "${#recall_rules[@]}" -gt 0 ]; then
      printf '## Situational Rules — Read When Triggered\n\n'
      printf 'These rules describe expectations that only apply to specific\n'
      printf 'kinds of work. When the trigger matches the current task, read\n'
      printf 'the file before acting on that work.\n\n'

      agent_guidelines_build_router_table \
        "${RULES_DIR}" "${RULE_STORE_PATH}" "${recall_rules[@]}"
      printf '\n'
    fi

    if [ "${#recall_skills[@]}" -gt 0 ]; then
      printf '## Situational Skills — Invoke When Triggered\n\n'
      printf 'These skills cover focused tasks that only apply in certain\n'
      printf 'situations. When the trigger matches the current task, invoke\n'
      printf 'the skill by name before acting on that work.\n\n'

      agent_guidelines_build_skill_router_table \
        "${SKILLS_DIR}" "${recall_skills[@]}"
      printf '\n'
    fi

    printf '%s\n' "$AGENT_GUIDELINES_MARKER_END"
  } > "$block_file"
}

install_context() {
  local block_file
  block_file="$(mktemp)"
  assemble_context_block "$block_file"

  section "Context Files"
  local item path label
  for item in "${CONTEXT_TARGETS[@]}"; do
    path="${item%%|*}"
    label="${item##*|}"

    if [ "$DRY_RUN" = true ]; then
      if [ -e "$path" ] &&
        grep -Fxq "$AGENT_GUIDELINES_MARKER_BEGIN" "$path" 2>/dev/null; then
        if agent_guidelines_extract_managed_block "$path" |
          cmp -s "$block_file" -; then
          entry "$GREEN" "✓" "current" "$path" "$label already up to date"
          CONTEXT_UNCHANGED=$((CONTEXT_UNCHANGED + 1))
        else
          entry "$CYAN" "?" "would update" "$path" "$label"
          CONTEXT_UPDATED=$((CONTEXT_UPDATED + 1))
        fi
      elif [ -e "$path" ]; then
        entry "$CYAN" "?" "would append" "$path" "$label"
        CONTEXT_UPDATED=$((CONTEXT_UPDATED + 1))
      else
        entry "$CYAN" "?" "would create" "$path" "$label"
        CONTEXT_CREATED=$((CONTEXT_CREATED + 1))
      fi
      continue
    fi

    agent_guidelines_make_directory_safely "$(dirname "$path")" ||
      die "could not create context directory for $path"
    local result
    result="$(agent_guidelines_update_managed_block "$path" "$block_file")"
    case "$result" in
      created)
        entry "$GREEN" "+" "created" "$path" "$label"
        CONTEXT_CREATED=$((CONTEXT_CREATED + 1))
        ;;
      updated)
        entry "$GREEN" "↻" "updated" "$path" "$label"
        CONTEXT_UPDATED=$((CONTEXT_UPDATED + 1))
        ;;
      unchanged)
        entry "$GREEN" "✓" "current" "$path" "$label"
        CONTEXT_UNCHANGED=$((CONTEXT_UNCHANGED + 1))
        ;;
    esac
  done

  rm -f "$block_file"
}

remove_context() {
  section "Context Files"
  local item path label
  for item in "${CONTEXT_TARGETS[@]}"; do
    path="${item%%|*}"
    label="${item##*|}"

    if [ "$DRY_RUN" = true ]; then
      if [ -e "$path" ] &&
        grep -Fxq "$AGENT_GUIDELINES_MARKER_BEGIN" "$path" 2>/dev/null; then
        entry "$CYAN" "?" "would clear" "$path" "$label"
        CONTEXT_REMOVED=$((CONTEXT_REMOVED + 1))
      else
        entry "$DIM" "·" "skipped" "$path" "$label not managed"
        CONTEXT_ABSENT=$((CONTEXT_ABSENT + 1))
      fi
      continue
    fi

    local result
    result="$(agent_guidelines_remove_managed_block "$path")"
    case "$result" in
      removed)
        entry "$RED" "-" "removed" "$path" "$label"
        CONTEXT_REMOVED=$((CONTEXT_REMOVED + 1))
        ;;
      cleared)
        entry "$RED" "↳" "cleared" "$path" "$label kept content outside markers"
        CONTEXT_CLEARED=$((CONTEXT_CLEARED + 1))
        ;;
      absent)
        entry "$DIM" "·" "absent" "$path" "$label has no managed block"
        CONTEXT_ABSENT=$((CONTEXT_ABSENT + 1))
        ;;
      missing)
        entry "$DIM" "·" "missing" "$path" "$label not present"
        CONTEXT_MISSING=$((CONTEXT_MISSING + 1))
        ;;
    esac
  done
}

# Reports each context file as current (managed block matches a fresh
# assembly), stale (managed block present but out of date; --install
# refreshes it), or missing (no managed block yet).
status_context() {
  local block_file
  block_file="$(mktemp)"
  assemble_context_block "$block_file"

  section "Context Files"
  local item path label
  for item in "${CONTEXT_TARGETS[@]}"; do
    path="${item%%|*}"
    label="${item##*|}"

    if [ -e "$path" ] &&
      grep -Fxq "$AGENT_GUIDELINES_MARKER_BEGIN" "$path" 2>/dev/null; then
      if agent_guidelines_extract_managed_block "$path" |
        cmp -s "$block_file" -; then
        entry "$GREEN" "✓" "current" "$path" "$label"
        CONTEXT_UNCHANGED=$((CONTEXT_UNCHANGED + 1))
      else
        entry "$YELLOW" "!" "stale" "$path" "$label out of date; run --install"
        CONTEXT_STALE=$((CONTEXT_STALE + 1))
        WARNINGS=$((WARNINGS + 1))
      fi
    else
      entry "$DIM" "·" "missing" "$path" "$label not yet assembled"
      CONTEXT_MISSING=$((CONTEXT_MISSING + 1))
    fi
  done

  rm -f "$block_file"
}

# Reports symlinks in managed directories whose resolved targets point into
# this repository but whose paths are outside the current managed set. These
# links lack ownership records, so prune leaves them unchanged.
prune_orphans() {
  section "Orphan Links"

  local managed_paths=()
  local ambiguous_count=0
  local link_entry rest link_path
  for link_entry in "${LINKS[@]}"; do
    rest="${link_entry#*|}"
    link_path="${rest%%|*}"
    managed_paths+=("$link_path")
  done

  local rules_real skills_real
  rules_real="$(real_path "$RULES_DIR")"
  skills_real="$(real_path "$SKILLS_DIR")"

  # ~/.claude/rules is scanned even though no links are installed
  # there today, so per-rule symlinks left behind by earlier installs
  # are cleaned up.
  local scan_dirs=("${HOME}/.claude/rules")
  local harness
  for harness in "${SKILL_HARNESSES[@]}"; do
    scan_dirs+=("$harness")
  done

  local scan_dir target matched m
  for scan_dir in "${scan_dirs[@]}"; do
    [ -d "$scan_dir" ] || continue
    while IFS= read -r -d '' link_path; do
      target="$(link_target "$link_path")"

      case "$target" in
        "$rules_real"/*|"$skills_real"/*) ;;
        *) continue ;;
      esac

      matched=false
      for m in "${managed_paths[@]}"; do
        if [ "$m" = "$link_path" ]; then
          matched=true
          break
        fi
      done
      [ "$matched" = true ] && continue

      entry "$YELLOW" "!" "ambiguous" "$link_path" \
        "unowned link left unchanged -> $target"
      SKIPPED=$((SKIPPED + 1))
      WARNINGS=$((WARNINGS + 1))
      ambiguous_count=$((ambiguous_count + 1))
    done < <(find "$scan_dir" -maxdepth 1 -type l -print0 2>/dev/null)
  done

  if [ "$ambiguous_count" -eq 0 ]; then
    entry "$DIM" "·" "none" "managed dirs" "no unowned links found"
  fi
}

print_summary() {
  section "Summary"
  summary_entry() {
    printf '  %-12s %s\n' "$1" "$2"
  }

  summary_entry "action:" "$ACTION"

  case "$ACTION" in
    status)
      summary_entry "current:" "$CURRENT"
      summary_entry "missing:" "$MISSING"
      summary_entry "conflicts:" "$CONFLICTS"
      summary_entry "context current:" "$CONTEXT_UNCHANGED"
      summary_entry "context stale:" "$CONTEXT_STALE"
      summary_entry "context missing:" "$CONTEXT_MISSING"
      ;;
    install)
      summary_entry "dry run:" "$DRY_RUN"
      summary_entry "forced:" "$FORCE"
      summary_entry "backup path:" "${BACKUP_RUN_DIR:-$BACKUP_PATH}"
      summary_entry "created:" "$CREATED"
      summary_entry "current:" "$CURRENT"
      summary_entry "context created:" "$CONTEXT_CREATED"
      summary_entry "context updated:" "$CONTEXT_UPDATED"
      summary_entry "context current:" "$CONTEXT_UNCHANGED"
      summary_entry "backups:" "$BACKED_UP"
      summary_entry "skipped:" "$SKIPPED"
      summary_entry "warnings:" "$WARNINGS"
      ;;
    remove)
      summary_entry "dry run:" "$DRY_RUN"
      summary_entry "removed:" "$REMOVED"
      summary_entry "context removed:" "$CONTEXT_REMOVED"
      summary_entry "context cleared:" "$CONTEXT_CLEARED"
      summary_entry "skipped:" "$SKIPPED"
      ;;
    prune)
      summary_entry "dry run:" "$DRY_RUN"
      summary_entry "pruned:" "$PRUNED"
      summary_entry "skipped:" "$SKIPPED"
      summary_entry "warnings:" "$WARNINGS"
      ;;
  esac

  printf '\n'
}

main() {
  parse_args "$@"
  setup_colors
  build_links
  validate_sources
  case "$ACTION" in
    install)
      preflight_context_targets
      preflight_links
      [ "$DRY_RUN" = true ] || agent_guidelines_transaction_begin
      process_links
      install_context
      [ "$DRY_RUN" = true ] || agent_guidelines_transaction_commit
      ;;
    remove)
      preflight_context_targets
      preflight_links
      [ "$DRY_RUN" = true ] || agent_guidelines_transaction_begin
      process_links
      remove_context
      [ "$DRY_RUN" = true ] || agent_guidelines_transaction_commit
      ;;
    status)  preflight_links; process_links; status_context ;;
    prune)   prune_orphans ;;
  esac
  print_summary
}

main "$@"
