#!/usr/bin/env bash
# Sets up a target repository with shared project rules and local git policy.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ASSET_DIR="${SCRIPT_DIR}/skills/project-setup/assets"
CANONICAL_RULES_DIR="${SCRIPT_DIR}/rules"
CANONICAL_SKILLS_DIR="${SCRIPT_DIR}/skills"

# shellcheck source=lib/assemble-rules.sh
. "${SCRIPT_DIR}/lib/assemble-rules.sh"
# shellcheck source=lib/safe-mutations.sh
. "${SCRIPT_DIR}/lib/safe-mutations.sh"

MODE="install"
PROFILE="auto"
CHANGELOG_MODE="auto"
CONTEXT_RULES_MODE="auto"
RULE_SOURCE_MODE="symlink"
SKILL_SOURCE_MODE=""
DEFAULT_BRANCH=""
TARGET_DIR="."
DRY_RUN=false
PROFILE_SUPPLIED=false
CHANGELOG_MODE_SUPPLIED=false
CONTEXT_RULES_MODE_SUPPLIED=false
RULE_SOURCE_MODE_SUPPLIED=false
SKILL_SOURCE_MODE_SUPPLIED=false
DEFAULT_BRANCH_SUPPLIED=false
INCLUDE_RULES=()
EXCLUDE_RULES=()
INCLUDE_SKILLS=()
EXCLUDE_SKILLS=()
REQUESTED_INCLUDE_RULES=()
REQUESTED_EXCLUDE_RULES=()
REQUESTED_INCLUDE_SKILLS=()
REQUESTED_EXCLUDE_SKILLS=()
STORED_INCLUDE_SKILLS=()
STORED_EXCLUDE_SKILLS=()
STORED_RULE_SOURCE_MODE=""
STORED_SKILL_SOURCE_MODE=""
LOADED_PROFILE=""
LOADED_CHANGELOG_MODE=""
LOADED_CONTEXT_RULES_MODE=""
LOADED_RULE_SOURCE_MODE=""
LOADED_SKILL_SOURCE_MODE=""
LOADED_DEFAULT_BRANCH=""
CONFIG_LOADED=false
GIT_USER_NAME=""
GIT_USER_EMAIL=""
STAGED_GIT_PARENT=""
STAGED_GIT_DIR=""

CREATED=()
UPDATED=()
UNCHANGED=()
SKIPPED=()
WARNINGS=()

# Profile rule lists and the canonical order are also documented in
# skills/project-setup/SKILL.md for environments without this script;
# keep the two in sync.
MINIMAL_RULES=(
  agent-conduct
  git-workflow
  git-messages
  no-plans-on-main
  merge-requests
  development-attribution
  configuration
  testing
  documentation
)

CODEBASE_EXTRA_RULES=(
  docstrings
  dependencies
  scripts
  code-quality
  debugging
  error-handling
  engineering-judgment
  environment-hygiene
  performance
)

RELEASED_EXTRA_RULES=(
  backward-compatibility
)

CANONICAL_RULE_ORDER=(
  agent-conduct
  git-workflow
  git-messages
  no-plans-on-main
  merge-requests
  development-attribution
  configuration
  testing
  documentation
  docstrings
  scripts
  code-quality
  debugging
  error-handling
  engineering-judgment
  environment-hygiene
  performance
  dependencies
  changelog-common
  changelog-date
  changelog-version
  versioning-semver
  backward-compatibility
)

usage() {
  cat <<'EOF'
Usage: ./project-setup.sh [options] [target-dir]

Options:
  --profile minimal|codebase|released
  --changelog none|date|version
                  aliases: dated, dates, versioned, versions
  --context-rules full|trimmed|auto
                  full: inline every selected rule body into the
                  project CLAUDE.md/AGENTS.md blocks
                  trimmed: emit the selection header and a router
                  table pointing at .agent-guidelines/rules instead,
                  relying on the global context for always-tier rules
                  auto (default): trimmed per file when the matching
                  global context file installed by setup.sh is
                  present, full otherwise
  --rules-source symlink|copy
  --skills-source symlink|copy   (defaults to --rules-source)
  --default-branch <name>        preserve this branch as repository default
                                 when automatic detection is ambiguous
  --remove        remove exact managed blocks, links, and recorded local
                  state whose current values still match, leaving legacy
                  state, project artifacts, and user content in place
  --include-rule <id>            (repeatable)
  --exclude-rule <id>            (repeatable)
  --include-skill <id>           (repeatable)
  --exclude-skill <id>           (repeatable)
  --dry-run                      preview actions without modifying anything
  -h, --help

Dry-run notes:
  Previews structural changes (created vs updated vs unchanged) without
  writing files, creating symlinks, configuring git, installing hooks,
  or making commits. Most accurate when the target directory already
  contains a git repository; on a fresh non-git directory the preview
  reports the repo init step and skips git-dependent previews.

Examples:
  ./project-setup.sh .
  ./project-setup.sh --profile codebase .
  ./project-setup.sh --profile released --changelog version .
  ./project-setup.sh --profile codebase --changelog date --include-rule docstrings .
  ./project-setup.sh --include-skill test-audit --include-skill firmware-review .
EOF
}

add_status() {
  local bucket="$1"
  local message="$2"

  case "$bucket" in
    created) CREATED+=("$message") ;;
    updated) UPDATED+=("$message") ;;
    unchanged) UNCHANGED+=("$message") ;;
    skipped) SKIPPED+=("$message") ;;
    warning) WARNINGS+=("$message") ;;
  esac
}

should_mutate() {
  [ "$DRY_RUN" != true ]
}

validate_git_environment() {
  local variable

  for variable in \
    GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
    GIT_ALTERNATE_OBJECT_DIRECTORIES; do
    if [ -n "${!variable:-}" ]; then
      die "$variable must be unset so setup can isolate the target repository"
    fi
  done
}

target_has_git_repo() {
  git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

validate_catalog_id() {
  local kind="$1"
  local identifier="$2"

  case "$identifier" in
    ""|-*|*-|*--*|*[!a-z0-9-]*)
      die "invalid $kind identifier: $identifier"
      ;;
  esac
}

validate_catalog_ids() {
  local identifier

  for identifier in \
    "${REQUESTED_INCLUDE_RULES[@]}" \
    "${REQUESTED_EXCLUDE_RULES[@]}"; do
    validate_catalog_id rule "$identifier"
  done
  for identifier in \
    "${REQUESTED_INCLUDE_SKILLS[@]}" \
    "${REQUESTED_EXCLUDE_SKILLS[@]}"; do
    validate_catalog_id skill "$identifier"
  done
}

array_contains() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

validate_selection_requests() {
  local identifier
  local seen=()

  for identifier in "${REQUESTED_INCLUDE_RULES[@]}"; do
    array_contains "$identifier" "${seen[@]}" &&
      die "duplicate --include-rule value: $identifier"
    seen+=("$identifier")
  done

  seen=()
  for identifier in "${REQUESTED_EXCLUDE_RULES[@]}"; do
    array_contains "$identifier" "${seen[@]}" &&
      die "duplicate --exclude-rule value: $identifier"
    seen+=("$identifier")
  done

  seen=()
  for identifier in "${REQUESTED_INCLUDE_SKILLS[@]}"; do
    array_contains "$identifier" "${seen[@]}" &&
      die "duplicate --include-skill value: $identifier"
    seen+=("$identifier")
  done

  seen=()
  for identifier in "${REQUESTED_EXCLUDE_SKILLS[@]}"; do
    array_contains "$identifier" "${seen[@]}" &&
      die "duplicate --exclude-skill value: $identifier"
    seen+=("$identifier")
  done
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --profile)
        [ "$#" -ge 2 ] || die "--profile requires a value"
        PROFILE="$2"
        PROFILE_SUPPLIED=true
        shift 2
        ;;
      --changelog)
        [ "$#" -ge 2 ] || die "--changelog requires a value"
        CHANGELOG_MODE="$2"
        CHANGELOG_MODE_SUPPLIED=true
        shift 2
        ;;
      --context-rules)
        [ "$#" -ge 2 ] || die "--context-rules requires a value"
        CONTEXT_RULES_MODE="$2"
        CONTEXT_RULES_MODE_SUPPLIED=true
        shift 2
        ;;
      --rules-source)
        [ "$#" -ge 2 ] || die "--rules-source requires a value"
        RULE_SOURCE_MODE="$2"
        RULE_SOURCE_MODE_SUPPLIED=true
        shift 2
        ;;
      --skills-source)
        [ "$#" -ge 2 ] || die "--skills-source requires a value"
        SKILL_SOURCE_MODE="$2"
        SKILL_SOURCE_MODE_SUPPLIED=true
        shift 2
        ;;
      --default-branch)
        [ "$#" -ge 2 ] || die "--default-branch requires a value"
        DEFAULT_BRANCH="$2"
        DEFAULT_BRANCH_SUPPLIED=true
        shift 2
        ;;
      --include-rule)
        [ "$#" -ge 2 ] || die "--include-rule requires a value"
        REQUESTED_INCLUDE_RULES+=("$2")
        shift 2
        ;;
      --exclude-rule)
        [ "$#" -ge 2 ] || die "--exclude-rule requires a value"
        REQUESTED_EXCLUDE_RULES+=("$2")
        shift 2
        ;;
      --include-skill)
        [ "$#" -ge 2 ] || die "--include-skill requires a value"
        REQUESTED_INCLUDE_SKILLS+=("$2")
        shift 2
        ;;
      --exclude-skill)
        [ "$#" -ge 2 ] || die "--exclude-skill requires a value"
        REQUESTED_EXCLUDE_SKILLS+=("$2")
        shift 2
        ;;
      --remove)
        MODE="remove"
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        die "unknown option: $1"
        ;;
      *)
        TARGET_DIR="$1"
        shift
        ;;
    esac
  done

  case "$PROFILE" in auto|minimal|codebase|released) ;; *) die "invalid profile: $PROFILE" ;; esac
  case "$CHANGELOG_MODE" in
    dated|dates)
      CHANGELOG_MODE="date"
      ;;
    versioned|versions)
      CHANGELOG_MODE="version"
      ;;
  esac
  case "$CHANGELOG_MODE" in auto|none|date|version) ;; *) die "invalid changelog mode: $CHANGELOG_MODE" ;; esac
  case "$CONTEXT_RULES_MODE" in auto|full|trimmed) ;; *) die "invalid context rules mode: $CONTEXT_RULES_MODE" ;; esac
  case "$RULE_SOURCE_MODE" in symlink|copy) ;; *) die "invalid rules source mode: $RULE_SOURCE_MODE" ;; esac
  if [ -z "$SKILL_SOURCE_MODE" ] && [ "$SKILL_SOURCE_MODE_SUPPLIED" = true ]; then
    SKILL_SOURCE_MODE="$RULE_SOURCE_MODE"
  fi
  case "$SKILL_SOURCE_MODE" in ""|symlink|copy) ;; *) die "invalid skills source mode: $SKILL_SOURCE_MODE" ;; esac
  validate_catalog_ids
  validate_selection_requests
}

resolve_target() {
  if [ ! -d "$TARGET_DIR" ]; then
    local candidate existing_parent worktree_root
    candidate="$(agent_guidelines_physical_candidate "$TARGET_DIR")" ||
      die "could not resolve target path: $TARGET_DIR"
    existing_parent="$(dirname "$candidate")"
    while [ ! -d "$existing_parent" ]; do
      existing_parent="$(dirname "$existing_parent")"
    done
    if git -C "$existing_parent" rev-parse --is-inside-work-tree \
      >/dev/null 2>&1; then
      worktree_root="$(git -C "$existing_parent" rev-parse --show-toplevel)"
      worktree_root="$(cd "$worktree_root" && pwd -P)"
      case "$candidate" in
        "$worktree_root"/*)
          die "target must not be created below repository worktree root $worktree_root: $candidate"
          ;;
      esac
    fi
  fi
  if should_mutate; then
    mkdir -p "$TARGET_DIR"
  elif [ ! -d "$TARGET_DIR" ]; then
    die "--dry-run target directory does not exist: $TARGET_DIR"
  fi
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd -P)"
}

validate_target_worktree_root() {
  target_has_git_repo || return 0

  local worktree_root
  worktree_root="$(git -C "$TARGET_DIR" rev-parse --show-toplevel)" ||
    die "could not resolve target worktree root: $TARGET_DIR"
  worktree_root="$(cd "$worktree_root" && pwd -P)"
  if [ "$worktree_root" != "$TARGET_DIR" ]; then
    die "target must be the repository worktree root $worktree_root: $TARGET_DIR"
  fi
}

require_git_identity() {
  command -v git >/dev/null 2>&1 || die "git is required"

  GIT_USER_NAME="$(git -C "$TARGET_DIR" config --get user.name || true)"
  GIT_USER_EMAIL="$(git -C "$TARGET_DIR" config --get user.email || true)"

  if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
    cat >&2 <<'EOF'
git user.name and user.email must be configured before setup can continue.

Run:
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
EOF
    exit 1
  fi
}

validate_default_branch_name() {
  local branch="$1"

  git check-ref-format --branch "$branch" >/dev/null 2>&1 ||
    die "invalid default branch name: $branch"
}

target_branch_exists() {
  local branch="$1"
  local current

  if git -C "$TARGET_DIR" show-ref --verify --quiet "refs/heads/$branch"; then
    return 0
  fi
  current="$(git -C "$TARGET_DIR" symbolic-ref --quiet --short HEAD \
    2>/dev/null || true)"
  [ "$current" = "$branch" ] &&
    ! git -C "$TARGET_DIR" rev-parse --verify --quiet HEAD >/dev/null 2>&1
}

resolve_remote_default_candidates() {
  local symref remainder branch
  local candidates=()

  while IFS= read -r symref; do
    [ -n "$symref" ] || continue
    remainder="${symref#refs/remotes/}"
    branch="${remainder#*/}"
    [ "$branch" != "$remainder" ] || continue
    target_branch_exists "$branch" || continue
    array_contains "$branch" "${candidates[@]}" ||
      candidates+=("$branch")
  done < <(git -C "$TARGET_DIR" for-each-ref \
    --format='%(symref)' 'refs/remotes/*/HEAD')

  if [ "${#candidates[@]}" -eq 1 ]; then
    printf '%s\n' "${candidates[0]}"
    return 0
  fi
  if [ "${#candidates[@]}" -gt 1 ]; then
    printf 'error: remote default branches disagree; use --default-branch\n' \
      >&2
    return 2
  fi
  return 1
}

resolve_default_branch() {
  local current=""
  local remote_default=""
  local remote_status
  local local_branches=()
  local branch

  if [ -n "$DEFAULT_BRANCH" ]; then
    validate_default_branch_name "$DEFAULT_BRANCH"
    if target_has_git_repo && ! target_branch_exists "$DEFAULT_BRANCH"; then
      die "selected default branch does not exist in target: $DEFAULT_BRANCH"
    fi
    printf 'Default branch policy: %s\n' "$DEFAULT_BRANCH"
    return
  fi

  if ! target_has_git_repo; then
    DEFAULT_BRANCH=main
    printf 'Default branch policy: %s\n' "$DEFAULT_BRANCH"
    return
  fi

  current="$(git -C "$TARGET_DIR" symbolic-ref --quiet --short HEAD \
    2>/dev/null || true)"
  if ! git -C "$TARGET_DIR" rev-parse --verify --quiet HEAD >/dev/null 2>&1;
  then
    [ -n "$current" ] ||
      die "cannot resolve unborn default branch; use --default-branch"
    DEFAULT_BRANCH="$current"
  else
    if remote_default="$(resolve_remote_default_candidates)"; then
      DEFAULT_BRANCH="$remote_default"
    else
      remote_status=$?
      [ "$remote_status" -eq 1 ] || exit "$remote_status"
      while IFS= read -r branch; do
        [ -n "$branch" ] && local_branches+=("$branch")
      done < <(git -C "$TARGET_DIR" for-each-ref \
        --format='%(refname:short)' refs/heads)

      if [ "${#local_branches[@]}" -eq 1 ]; then
        DEFAULT_BRANCH="${local_branches[0]}"
      elif [ "$current" = main ] || [ "$current" = master ]; then
        DEFAULT_BRANCH="$current"
      else
        die "default branch is ambiguous; use --default-branch"
      fi
    fi
  fi

  validate_default_branch_name "$DEFAULT_BRANCH"
  case "$DEFAULT_BRANCH" in
    feat/*|fix/*|chore/*|docs/*|refactor/*|test/*|build/*|ci/*|perf/*|style/*|revert/*)
      die "detected typed work branch as default; use --default-branch to confirm: $DEFAULT_BRANCH"
      ;;
  esac
  printf 'Default branch policy: %s\n' "$DEFAULT_BRANCH"
}

init_git_if_needed() {
  if target_has_git_repo; then
    add_status unchanged "git repository already exists"
    REPO_CREATED=false
    return
  fi

  if should_mutate; then
    STAGED_GIT_PARENT="$(mktemp -d \
      "$(dirname "$TARGET_DIR")/.agent-guidelines-git.XXXXXX")" ||
      die "could not create staged Git directory beside $TARGET_DIR"
    STAGED_GIT_DIR="$STAGED_GIT_PARENT/git"
    agent_guidelines_transaction_set_recovery_note \
      "staged Git directory: $STAGED_GIT_DIR"
    if ! git --git-dir="$STAGED_GIT_DIR" --work-tree="$TARGET_DIR" \
      init --initial-branch="$DEFAULT_BRANCH" >/dev/null; then
      die "could not initialize staged Git directory: $STAGED_GIT_DIR"
    fi
    export GIT_DIR="$STAGED_GIT_DIR"
    export GIT_WORK_TREE="$TARGET_DIR"
  fi
  add_status created "git repository"
  REPO_CREATED=true
}

finalize_staged_git_repository() {
  [ "${REPO_CREATED:-false}" = true ] || return 0
  should_mutate || return 0

  local target_git_dir="$TARGET_DIR/.git"
  local transaction_entry

  [ -n "$STAGED_GIT_DIR" ] && [ -d "$STAGED_GIT_DIR" ] ||
    die "staged Git directory is unavailable: $STAGED_GIT_DIR"
  [ ! -e "$target_git_dir" ] && [ ! -L "$target_git_dir" ] ||
    die "target Git path appeared during setup: $target_git_dir"

  unset GIT_DIR GIT_WORK_TREE
  agent_guidelines_transaction_discard_entries_beneath "$STAGED_GIT_DIR" ||
    die "could not consolidate staged Git recovery entries"
  transaction_entry="$(agent_guidelines_transaction_allocate_entry \
    "$target_git_dir" directory "$STAGED_GIT_DIR")" ||
    die "could not protect final Git directory installation"
  if ! mv "$STAGED_GIT_DIR" "$target_git_dir"; then
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || true
    die "could not install the staged Git directory: $target_git_dir"
  fi
  if ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || true
    die "could not verify the installed Git directory: $target_git_dir"
  fi
  rmdir "$STAGED_GIT_PARENT" ||
    die "could not remove empty staged Git parent: $STAGED_GIT_PARENT"
  STAGED_GIT_PARENT=""
  STAGED_GIT_DIR=""
  agent_guidelines_transaction_set_recovery_note ""
}

preflight_existing_unborn_index() {
  target_has_git_repo || return 0
  git -C "$TARGET_DIR" rev-parse --verify --quiet HEAD >/dev/null 2>&1 &&
    return 0

  if ! git -C "$TARGET_DIR" diff --cached --quiet; then
    die "unborn target repository has staged content; clear or commit its index before setup"
  fi
}

infer_profile() {
  if [ "$PROFILE" != "auto" ]; then
    return
  fi

  if [ -f "$TARGET_DIR/CHANGELOG.md" ] &&
    grep -Eq '^## \[Unreleased\]|^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}' "$TARGET_DIR/CHANGELOG.md"; then
    PROFILE="released"
  elif [ -f "$TARGET_DIR/package.json" ] || [ -f "$TARGET_DIR/pyproject.toml" ] ||
    [ -f "$TARGET_DIR/Cargo.toml" ] || [ -f "$TARGET_DIR/go.mod" ] ||
    [ -f "$TARGET_DIR/VERSION" ]; then
    PROFILE="released"
  elif [ -n "$(find "$TARGET_DIR" -maxdepth 3 -type f \( \
    -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' -o \
    -name '*.go' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o \
    -name '*.tsx' -o -name '*.py' -o -name '*.rs' -o -name '*.java' -o \
    -name '*.sh' \) | sed -n '1p')" ]; then
    PROFILE="codebase"
  else
    PROFILE="minimal"
  fi
}

infer_changelog_mode() {
  if [ "$CHANGELOG_MODE" != "auto" ]; then
    return
  fi

  if [ -f "$TARGET_DIR/CHANGELOG.md" ] &&
    grep -Eq '^## \[Unreleased\]|^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}' "$TARGET_DIR/CHANGELOG.md"; then
    CHANGELOG_MODE="version"
  elif [ -f "$TARGET_DIR/CHANGELOG.md" ] &&
    grep -Eq '^## [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$TARGET_DIR/CHANGELOG.md"; then
    CHANGELOG_MODE="date"
  elif [ "$PROFILE" = "released" ]; then
    CHANGELOG_MODE="version"
  else
    CHANGELOG_MODE="none"
  fi
}

versioning_mode() {
  if [ "$CHANGELOG_MODE" = "version" ]; then
    printf 'semver'
  else
    printf 'none'
  fi
}

write_file_if_missing() {
  local path="$1"
  local source="$2"
  local label="$3"

  if [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
    die "$label exists and is not a regular file: $path"
  fi
  if [ -e "$path" ]; then
    add_status unchanged "$label"
    return
  fi

  if should_mutate; then
    agent_guidelines_make_directory_safely "$(dirname "$path")" ||
      die "could not create parent directory for $label"
    agent_guidelines_replace_file_safely "$path" "$source" ||
      die "could not create $label"
  fi
  add_status created "$label"
}

write_readme_if_missing() {
  local path="$TARGET_DIR/README.md"

  if [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
    die "README.md exists and is not a regular file: $path"
  fi
  if [ -e "$path" ]; then
    add_status unchanged "README.md"
    return
  fi

  if should_mutate; then
    local prepared
    prepared="$(mktemp)"
    printf '# %s\n\n' "$(basename "$TARGET_DIR")" > "$prepared"
    if ! agent_guidelines_replace_file_safely "$path" "$prepared"; then
      rm -f "$prepared"
      die "could not create README.md"
    fi
    rm -f "$prepared"
  fi
  add_status created "README.md"
}

configure_commit_template() {
  if ! target_has_git_repo; then
    add_status skipped "git commit.template (target has no git repo)"
    return
  fi

  local current
  current="$(git -C "$TARGET_DIR" config --local --get commit.template || true)"

  if [ "$current" = ".gittemplate" ]; then
    add_status unchanged "git commit.template"
  elif [ -n "$current" ]; then
    die "git commit.template is user-managed: $current"
  else
    if should_mutate; then
      mutate_local_git_config commit.template .gittemplate ||
        die "could not set git commit.template"
      if ! write_ownership_record \
        commit-template 'created=.gittemplate'; then
        die "could not record commit.template ownership"
      fi
    fi
    add_status updated "git commit.template"
  fi
}

git_path() {
  local path
  path="$(git -C "$TARGET_DIR" rev-parse --git-path "$1")"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$TARGET_DIR" "$path" ;;
  esac
}

git_metadata_root() {
  git -C "$TARGET_DIR" rev-parse --absolute-git-dir
}

assert_local_git_path() {
  local path="$1"
  local label="$2"

  agent_guidelines_assert_path_beneath \
    "$path" "$(git_metadata_root)" "$label"
}

mutate_local_git_config() {
  local config_path
  local transaction_entry=""

  config_path="$(git_path config)"
  assert_local_git_path "$config_path" "git config" || return 1
  if agent_guidelines_transaction_is_active; then
    transaction_entry="$(agent_guidelines_transaction_allocate_entry \
      "$config_path" unknown)" || return 1
  fi
  if ! git -C "$TARGET_DIR" config --local "$@"; then
    [ -z "$transaction_entry" ] ||
      agent_guidelines_transaction_cancel_entry "$transaction_entry"
    return 1
  fi
  if [ -n "$transaction_entry" ] &&
    ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || true
    return 1
  fi
}

make_file_executable_safely() {
  local path="$1"
  local transaction_entry=""

  if agent_guidelines_transaction_is_active; then
    transaction_entry="$(agent_guidelines_transaction_allocate_entry \
      "$path" unknown)" || return 1
  fi
  if ! chmod +x "$path"; then
    [ -z "$transaction_entry" ] ||
      agent_guidelines_transaction_cancel_entry "$transaction_entry"
    return 1
  fi
  if [ -n "$transaction_entry" ] &&
    ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || true
    return 1
  fi
}

create_managed_symlink_safely() {
  local target="$1"
  local source="$2"
  local transaction_entry=""

  if agent_guidelines_transaction_is_active; then
    transaction_entry="$(agent_guidelines_transaction_allocate_entry \
      "$target" symlink "$source")" || return 1
  fi
  if ! ln -s "$source" "$target"; then
    [ -z "$transaction_entry" ] ||
      agent_guidelines_transaction_cancel_entry "$transaction_entry"
    return 1
  fi
  if [ -n "$transaction_entry" ] &&
    ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || true
    return 1
  fi
}

copy_managed_directory_safely() {
  local target="$1"
  local source="$2"
  local parent
  local stage_dir
  local staged
  local transaction_entry=""

  parent="$(dirname "$target")"
  stage_dir="$(mktemp -d "${parent}/.agent-guidelines-copy.XXXXXX")" || return 1
  staged="$stage_dir/object"
  if ! agent_guidelines_backup_object "$source" "$staged"; then
    rm -rf "$stage_dir"
    return 1
  fi
  if agent_guidelines_transaction_is_active; then
    transaction_entry="$(agent_guidelines_transaction_allocate_entry \
      "$target" directory "$staged")" || {
      rm -rf "$stage_dir"
      return 1
    }
  fi
  if ! mv "$staged" "$target"; then
    [ -z "$transaction_entry" ] ||
      agent_guidelines_transaction_cancel_entry "$transaction_entry"
    rm -rf "$stage_dir"
    return 1
  fi
  rmdir "$stage_dir"
  if [ -n "$transaction_entry" ] &&
    ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || true
    return 1
  fi
}

remove_managed_symlink_safely() {
  local target="$1"
  local transaction_entry=""

  if agent_guidelines_transaction_is_active; then
    transaction_entry="$(agent_guidelines_transaction_allocate_entry \
      "$target" missing)" || return 1
  fi
  if ! rm -f "$target"; then
    [ -z "$transaction_entry" ] ||
      agent_guidelines_transaction_cancel_entry "$transaction_entry"
    return 1
  fi
  if [ -n "$transaction_entry" ] &&
    ! agent_guidelines_transaction_complete_entry "$transaction_entry"; then
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || true
    return 1
  fi
}

remove_managed_directory_safely() {
  local target="$1"
  local transaction_entry

  agent_guidelines_transaction_is_active || {
    printf 'error: managed directory removal requires a transaction: %s\n' \
      "$target" >&2
    return 1
  }
  transaction_entry="$(agent_guidelines_transaction_allocate_entry \
    "$target" missing)" || return 1
  if rm -rf "$target" && [ ! -e "$target" ] && [ ! -L "$target" ]; then
    if agent_guidelines_transaction_complete_entry "$transaction_entry"; then
      return 0
    fi
  fi
  agent_guidelines_transaction_cancel_entry "$transaction_entry" || return 1
  printf 'error: safe managed directory removal failed: %s\n' "$target" >&2
  return 1
}

sha256_file() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{ print $1 }'
  else
    shasum -a 256 "$path" | awk '{ print $1 }'
  fi
}

validate_state_scalar() {
  local key="$1"
  local value="$2"

  case "$key" in
    profile)
      case "$value" in minimal|codebase|released) ;; *) return 1 ;; esac
      ;;
    changelog)
      case "$value" in none|date|version) ;; *) return 1 ;; esac
      ;;
    context_rules)
      case "$value" in auto|full|trimmed) ;; *) return 1 ;; esac
      ;;
    rules_source|skills_source)
      case "$value" in symlink|copy) ;; *) return 1 ;; esac
      ;;
    versioning)
      case "$value" in none|semver) ;; *) return 1 ;; esac
      ;;
    *) return 1 ;;
  esac
}

validate_loaded_selections() {
  local identifier

  for identifier in "${INCLUDE_RULES[@]}"; do
    validate_catalog_id rule "$identifier"
  done
  for identifier in "${EXCLUDE_RULES[@]}"; do
    validate_catalog_id rule "$identifier"
  done
  for identifier in "${INCLUDE_SKILLS[@]}"; do
    validate_catalog_id skill "$identifier"
  done
  for identifier in "${EXCLUDE_SKILLS[@]}"; do
    validate_catalog_id skill "$identifier"
  done
}

append_loaded_selection() {
  local kind="$1"
  local identifier="$2"

  case "$kind" in
    include_rule)
      array_contains "$identifier" "${INCLUDE_RULES[@]}" &&
        die "duplicate stored include_rule: $identifier"
      INCLUDE_RULES+=("$identifier")
      ;;
    exclude_rule)
      array_contains "$identifier" "${EXCLUDE_RULES[@]}" &&
        die "duplicate stored exclude_rule: $identifier"
      EXCLUDE_RULES+=("$identifier")
      ;;
    include_skill)
      array_contains "$identifier" "${INCLUDE_SKILLS[@]}" &&
        die "duplicate stored include_skill: $identifier"
      INCLUDE_SKILLS+=("$identifier")
      ;;
    exclude_skill)
      array_contains "$identifier" "${EXCLUDE_SKILLS[@]}" &&
        die "duplicate stored exclude_skill: $identifier"
      EXCLUDE_SKILLS+=("$identifier")
      ;;
    *) die "invalid stored selection kind: $kind" ;;
  esac
}

parse_schema_one_config() {
  local path="$1"
  local line key value
  local schema_seen=false
  local profile_seen=false
  local changelog_seen=false
  local context_seen=false
  local rules_source_seen=false
  local skills_source_seen=false
  local default_branch_seen=false

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *=*)
        key="${line%%=*}"
        value="${line#*=}"
        ;;
      *) die "malformed setup state line: $line" ;;
    esac

    case "$key" in
      schema)
        [ "$schema_seen" = false ] || die "duplicate setup state key: schema"
        [ "$value" = 1 ] || die "unsupported setup state schema: $value"
        schema_seen=true
        ;;
      profile)
        [ "$profile_seen" = false ] || die "duplicate setup state key: profile"
        validate_state_scalar profile "$value" ||
          die "invalid stored profile: $value"
        LOADED_PROFILE="$value"
        profile_seen=true
        ;;
      changelog)
        [ "$changelog_seen" = false ] || die "duplicate setup state key: changelog"
        validate_state_scalar changelog "$value" ||
          die "invalid stored changelog mode: $value"
        LOADED_CHANGELOG_MODE="$value"
        changelog_seen=true
        ;;
      context_rules)
        [ "$context_seen" = false ] || die "duplicate setup state key: context_rules"
        validate_state_scalar context_rules "$value" ||
          die "invalid stored context-rules mode: $value"
        LOADED_CONTEXT_RULES_MODE="$value"
        context_seen=true
        ;;
      rules_source)
        [ "$rules_source_seen" = false ] || die "duplicate setup state key: rules_source"
        validate_state_scalar rules_source "$value" ||
          die "invalid stored rules-source mode: $value"
        LOADED_RULE_SOURCE_MODE="$value"
        rules_source_seen=true
        ;;
      skills_source)
        [ "$skills_source_seen" = false ] || die "duplicate setup state key: skills_source"
        validate_state_scalar skills_source "$value" ||
          die "invalid stored skills-source mode: $value"
        LOADED_SKILL_SOURCE_MODE="$value"
        skills_source_seen=true
        ;;
      default_branch)
        [ "$default_branch_seen" = false ] ||
          die "duplicate setup state key: default_branch"
        [ -n "$value" ] || die "empty stored default branch"
        LOADED_DEFAULT_BRANCH="$value"
        default_branch_seen=true
        ;;
      include_rule|exclude_rule|include_skill|exclude_skill)
        [ -n "$value" ] || die "empty stored selection: $key"
        append_loaded_selection "$key" "$value"
        ;;
      *) die "unknown setup state key: $key" ;;
    esac
  done < "$path"

  [ "$schema_seen" = true ] || die "setup state is missing schema"
  [ "$profile_seen" = true ] || die "setup state is missing profile"
  [ "$changelog_seen" = true ] || die "setup state is missing changelog"
  [ "$context_seen" = true ] || die "setup state is missing context_rules"
  [ "$rules_source_seen" = true ] || die "setup state is missing rules_source"
  [ "$skills_source_seen" = true ] || die "setup state is missing skills_source"
}

append_legacy_selections() {
  local kind="$1"
  local value="$2"
  local identifiers=()
  local identifier

  [ -z "$value" ] || read -r -a identifiers <<< "$value"
  for identifier in "${identifiers[@]}"; do
    append_loaded_selection "$kind" "$identifier"
  done
}

parse_legacy_config() {
  local path="$1"
  local line key value
  local profile_seen=false
  local changelog_seen=false
  local versioning_seen=false
  local context_seen=false
  local rules_source_seen=false
  local skills_source_seen=false
  local include_rules_seen=false
  local exclude_rules_seen=false
  local include_skills_seen=false
  local exclude_skills_seen=false
  local legacy_versioning=""

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *=*)
        key="${line%%=*}"
        value="${line#*=}"
        ;;
      *) die "malformed legacy setup state line: $line" ;;
    esac

    case "$key" in
      profile)
        [ "$profile_seen" = false ] || die "duplicate legacy setup state key: profile"
        validate_state_scalar profile "$value" ||
          die "invalid legacy profile: $value"
        LOADED_PROFILE="$value"
        profile_seen=true
        ;;
      changelog)
        [ "$changelog_seen" = false ] || die "duplicate legacy setup state key: changelog"
        validate_state_scalar changelog "$value" ||
          die "invalid legacy changelog mode: $value"
        LOADED_CHANGELOG_MODE="$value"
        changelog_seen=true
        ;;
      versioning)
        [ "$versioning_seen" = false ] || die "duplicate legacy setup state key: versioning"
        validate_state_scalar versioning "$value" ||
          die "invalid legacy versioning mode: $value"
        legacy_versioning="$value"
        versioning_seen=true
        ;;
      context_rules)
        [ "$context_seen" = false ] || die "duplicate legacy setup state key: context_rules"
        validate_state_scalar context_rules "$value" ||
          die "invalid legacy context-rules mode: $value"
        LOADED_CONTEXT_RULES_MODE="$value"
        context_seen=true
        ;;
      rules_source)
        [ "$rules_source_seen" = false ] || die "duplicate legacy setup state key: rules_source"
        validate_state_scalar rules_source "$value" ||
          die "invalid legacy rules-source mode: $value"
        LOADED_RULE_SOURCE_MODE="$value"
        rules_source_seen=true
        ;;
      skills_source)
        [ "$skills_source_seen" = false ] || die "duplicate legacy setup state key: skills_source"
        validate_state_scalar skills_source "$value" ||
          die "invalid legacy skills-source mode: $value"
        LOADED_SKILL_SOURCE_MODE="$value"
        skills_source_seen=true
        ;;
      include_rules)
        [ "$include_rules_seen" = false ] || die "duplicate legacy setup state key: include_rules"
        append_legacy_selections include_rule "$value"
        include_rules_seen=true
        ;;
      exclude_rules)
        [ "$exclude_rules_seen" = false ] || die "duplicate legacy setup state key: exclude_rules"
        append_legacy_selections exclude_rule "$value"
        exclude_rules_seen=true
        ;;
      include_skills)
        [ "$include_skills_seen" = false ] || die "duplicate legacy setup state key: include_skills"
        append_legacy_selections include_skill "$value"
        include_skills_seen=true
        ;;
      exclude_skills)
        [ "$exclude_skills_seen" = false ] || die "duplicate legacy setup state key: exclude_skills"
        append_legacy_selections exclude_skill "$value"
        exclude_skills_seen=true
        ;;
      *) die "unknown legacy setup state key: $key" ;;
    esac
  done < "$path"

  [ "$profile_seen" = true ] || die "legacy setup state is missing profile"
  [ "$changelog_seen" = true ] || die "legacy setup state is missing changelog"
  [ "$versioning_seen" = true ] || die "legacy setup state is missing versioning"
  [ "$context_seen" = true ] || die "legacy setup state is missing context_rules"
  [ "$rules_source_seen" = true ] || die "legacy setup state is missing rules_source"
  [ "$skills_source_seen" = true ] || die "legacy setup state is missing skills_source"
  [ "$include_rules_seen" = true ] || die "legacy setup state is missing include_rules"
  [ "$exclude_rules_seen" = true ] || die "legacy setup state is missing exclude_rules"
  [ "$include_skills_seen" = true ] || die "legacy setup state is missing include_skills"
  [ "$exclude_skills_seen" = true ] || die "legacy setup state is missing exclude_skills"

  local expected_versioning=none
  [ "$LOADED_CHANGELOG_MODE" = version ] && expected_versioning=semver
  [ "$legacy_versioning" = "$expected_versioning" ] ||
    die "legacy setup state has inconsistent versioning mode"
}

parse_local_config() {
  local path="$1"
  local first_line

  if LC_ALL=C od -An -v -t x1 "$path" |
    grep -Eq '(^|[[:space:]])00([[:space:]]|$)'; then
    die "setup state contains NUL data: $path"
  fi

  INCLUDE_RULES=()
  EXCLUDE_RULES=()
  INCLUDE_SKILLS=()
  EXCLUDE_SKILLS=()
  first_line="$(sed -n '1p' "$path")"
  case "$first_line" in
    schema=*) parse_schema_one_config "$path" ;;
    *) parse_legacy_config "$path" ;;
  esac
  validate_loaded_selections
}

remove_rule_inclusion() {
  local needle="$1"
  local kept=()
  local item
  for item in "${INCLUDE_RULES[@]}"; do
    [ "$item" = "$needle" ] || kept+=("$item")
  done
  INCLUDE_RULES=("${kept[@]}")
}

remove_rule_exclusion() {
  local needle="$1"
  local kept=()
  local item
  for item in "${EXCLUDE_RULES[@]}"; do
    [ "$item" = "$needle" ] || kept+=("$item")
  done
  EXCLUDE_RULES=("${kept[@]}")
}

remove_skill_inclusion() {
  local needle="$1"
  local kept=()
  local item
  for item in "${INCLUDE_SKILLS[@]}"; do
    [ "$item" = "$needle" ] || kept+=("$item")
  done
  INCLUDE_SKILLS=("${kept[@]}")
}

remove_skill_exclusion() {
  local needle="$1"
  local kept=()
  local item
  for item in "${EXCLUDE_SKILLS[@]}"; do
    [ "$item" = "$needle" ] || kept+=("$item")
  done
  EXCLUDE_SKILLS=("${kept[@]}")
}

apply_selection_requests() {
  local identifier

  for identifier in "${REQUESTED_INCLUDE_RULES[@]}"; do
    array_contains "$identifier" "${REQUESTED_EXCLUDE_RULES[@]}" ||
      remove_rule_exclusion "$identifier"
    array_contains "$identifier" "${INCLUDE_RULES[@]}" ||
      INCLUDE_RULES+=("$identifier")
  done
  for identifier in "${REQUESTED_EXCLUDE_RULES[@]}"; do
    array_contains "$identifier" "${REQUESTED_INCLUDE_RULES[@]}" ||
      remove_rule_inclusion "$identifier"
    array_contains "$identifier" "${EXCLUDE_RULES[@]}" ||
      EXCLUDE_RULES+=("$identifier")
  done
  for identifier in "${REQUESTED_INCLUDE_SKILLS[@]}"; do
    array_contains "$identifier" "${REQUESTED_EXCLUDE_SKILLS[@]}" ||
      remove_skill_exclusion "$identifier"
    array_contains "$identifier" "${INCLUDE_SKILLS[@]}" ||
      INCLUDE_SKILLS+=("$identifier")
  done
  for identifier in "${REQUESTED_EXCLUDE_SKILLS[@]}"; do
    array_contains "$identifier" "${REQUESTED_INCLUDE_SKILLS[@]}" ||
      remove_skill_inclusion "$identifier"
    array_contains "$identifier" "${EXCLUDE_SKILLS[@]}" ||
      EXCLUDE_SKILLS+=("$identifier")
  done
}

load_local_config() {
  local config_path="$TARGET_DIR/.agent-guidelines/config"
  local config_record
  local checksum

  if [ ! -e "$config_path" ] && [ ! -L "$config_path" ]; then
    apply_selection_requests
    [ -n "$SKILL_SOURCE_MODE" ] || SKILL_SOURCE_MODE="$RULE_SOURCE_MODE"
    return
  fi
  [ -f "$config_path" ] && [ ! -L "$config_path" ] ||
    die "setup state is not a regular file: $config_path"
  target_has_git_repo ||
    die "setup state exists without repository ownership: $config_path"

  config_record="$(ownership_record_path config)"
  checksum="$(sha256_file "$config_path")"
  if [ -L "$config_record" ] || [ ! -f "$config_record" ] ||
    [ "$(wc -l < "$config_record")" -ne 1 ] ||
    ! grep -Fxq "sha256=$checksum" "$config_record"; then
    die "setup state is unowned or its checksum changed: $config_path"
  fi

  parse_local_config "$config_path"
  CONFIG_LOADED=true
  STORED_INCLUDE_SKILLS=("${INCLUDE_SKILLS[@]}")
  STORED_EXCLUDE_SKILLS=("${EXCLUDE_SKILLS[@]}")
  STORED_RULE_SOURCE_MODE="$LOADED_RULE_SOURCE_MODE"
  STORED_SKILL_SOURCE_MODE="$LOADED_SKILL_SOURCE_MODE"

  [ "$PROFILE_SUPPLIED" = true ] || PROFILE="$LOADED_PROFILE"
  [ "$CHANGELOG_MODE_SUPPLIED" = true ] ||
    CHANGELOG_MODE="$LOADED_CHANGELOG_MODE"
  [ "$CONTEXT_RULES_MODE_SUPPLIED" = true ] ||
    CONTEXT_RULES_MODE="$LOADED_CONTEXT_RULES_MODE"
  [ "$RULE_SOURCE_MODE_SUPPLIED" = true ] ||
    RULE_SOURCE_MODE="$LOADED_RULE_SOURCE_MODE"
  [ "$SKILL_SOURCE_MODE_SUPPLIED" = true ] ||
    SKILL_SOURCE_MODE="$LOADED_SKILL_SOURCE_MODE"
  if [ "$DEFAULT_BRANCH_SUPPLIED" = false ] &&
    [ -n "$LOADED_DEFAULT_BRANCH" ]; then
    DEFAULT_BRANCH="$LOADED_DEFAULT_BRANCH"
  fi

  apply_selection_requests
  [ -n "$SKILL_SOURCE_MODE" ] || SKILL_SOURCE_MODE="$RULE_SOURCE_MODE"
}

ownership_dir() {
  local path

  path="$(git_path agent-guidelines/ownership-v1)"
  assert_local_git_path "$path" "ownership state" || return 1
  printf '%s\n' "$path"
}

ownership_record_path() {
  local name="$1"

  printf '%s/%s\n' "$(ownership_dir)" "$name"
}

write_ownership_record() {
  local name="$1"
  local value="$2"
  local path
  local prepared

  path="$(ownership_record_path "$name")"
  prepared="$(mktemp)"
  printf '%s\n' "$value" > "$prepared"

  if [ -e "$path" ] && cmp -s "$path" "$prepared"; then
    rm -f "$prepared"
    return 0
  fi
  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -f "$prepared"
    printf 'error: ownership record conflicts: %s\n' "$path" >&2
    return 1
  fi

  agent_guidelines_make_directory_safely "$(dirname "$path")" || return 1
  if ! agent_guidelines_replace_file_safely "$path" "$prepared"; then
    rm -f "$prepared"
    return 1
  fi
  rm -f "$prepared"
}

replace_ownership_record() {
  local name="$1"
  local value="$2"
  local path
  local prepared

  path="$(ownership_record_path "$name")"
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  prepared="$(mktemp)"
  printf '%s\n' "$value" > "$prepared"
  agent_guidelines_replace_file_safely "$path" "$prepared"
  local result=$?
  rm -f "$prepared"
  return "$result"
}

exclude_record_name() {
  local key="$1"

  printf 'exclude-%s\n' "$key"
}

append_missing_line() {
  local file="$1"
  local line="$2"
  local label="$3"
  local key="$4"
  local record_name
  local prepared

  if [ -e "$file" ] && grep -Fxq "$line" "$file"; then
    add_status unchanged "$label"
    return
  fi

  if should_mutate; then
    record_name="$(exclude_record_name "$key")"
    write_ownership_record "$record_name" "line=$line" ||
      die "could not record ownership for $label"

    prepared="$(mktemp)"
    [ -e "$file" ] && cat "$file" > "$prepared"
    printf '%s\n' "$line" >> "$prepared"
    if ! agent_guidelines_replace_file_safely "$file" "$prepared"; then
      rm -f "$prepared"
      die "could not update $file"
    fi
    rm -f "$prepared"
  fi
  add_status updated "$label"
}

remove_owned_exclude_line() {
  local file="$1"
  local line="$2"
  local label="$3"
  local key="$4"
  local record_name record_path prepared

  record_name="$(exclude_record_name "$key")"
  record_path="$(ownership_record_path "$record_name")"
  if [ ! -e "$record_path" ] && [ ! -L "$record_path" ]; then
    add_status unchanged "$label (not owned)"
    return
  fi
  validate_ownership_record "$record_name" "line=$line"
  [ -f "$file" ] && [ ! -L "$file" ] ||
    die "owned exclude line has no regular exclude file: $line"
  [ "$(grep -Fxc "$line" "$file" || true)" -eq 1 ] ||
    die "owned exclude line no longer has one exact match: $line"

  if should_mutate; then
    prepared="$(mktemp)"
    grep -Fvx "$line" "$file" > "$prepared" || true
    if ! agent_guidelines_replace_file_safely "$file" "$prepared"; then
      rm -f "$prepared"
      die "could not remove $label"
    fi
    rm -f "$prepared"
    agent_guidelines_remove_file_safely "$record_path" ||
      die "could not remove ownership for $label"
  fi
  add_status updated "$label removed"
}

configure_local_excludes() {
  if ! target_has_git_repo; then
    add_status skipped "git info/exclude (target has no git repo)"
    return
  fi

  local exclude_file local_file key
  exclude_file="$(git_path info/exclude)"
  assert_local_git_path "$exclude_file" "git info/exclude" ||
    die "git exclude path escapes the repository Git directory"
  if should_mutate; then
    agent_guidelines_make_directory_safely "$(dirname "$exclude_file")" ||
      die "could not create git exclude directory"
  fi

  append_missing_line "$exclude_file" "CLAUDE.md" "exclude CLAUDE.md" claude
  append_missing_line "$exclude_file" "CLAUDE.local.md" "exclude CLAUDE.local.md" claude-local
  append_missing_line "$exclude_file" "AGENTS.md" "exclude AGENTS.md" agents
  append_missing_line "$exclude_file" ".claude/" "exclude .claude/" claude-dir
  append_missing_line "$exclude_file" ".codex/" "exclude .codex/" codex-dir
  append_missing_line "$exclude_file" ".agent-guidelines/config" "exclude .agent-guidelines/config" config
  if [ "$RULE_SOURCE_MODE" = "symlink" ]; then
    append_missing_line "$exclude_file" ".agent-guidelines/rules" \
      "exclude .agent-guidelines/rules symlink" rules
  else
    remove_owned_exclude_line "$exclude_file" ".agent-guidelines/rules" \
      "exclude .agent-guidelines/rules symlink" rules
  fi

  if [ "$SKILL_SOURCE_MODE" = symlink ] && has_selected_skills; then
    append_missing_line "$exclude_file" ".agents/skills/" \
      "exclude .agents/skills/" skills
  else
    remove_owned_exclude_line "$exclude_file" ".agents/skills/" \
      "exclude .agents/skills/" skills
  fi

  for local_file in opencode.json .mcp.json; do
    if git -C "$TARGET_DIR" ls-files --error-unmatch "$local_file" >/dev/null 2>&1; then
      add_status skipped "$local_file is tracked"
    else
      case "$local_file" in
        opencode.json) key=opencode ;;
        .mcp.json) key=mcp ;;
      esac
      append_missing_line "$exclude_file" "$local_file" \
        "exclude $local_file" "$key"
    fi
  done
}

configure_rule_source() {
  local state_dir="$TARGET_DIR/.agent-guidelines"
  local rules_path="$state_dir/rules"

  if should_mutate; then
    agent_guidelines_make_directory_safely "$state_dir" ||
      die "could not create .agent-guidelines directory"
  fi

  if [ "$CONFIG_LOADED" = true ] &&
    [ "$STORED_RULE_SOURCE_MODE" != "$RULE_SOURCE_MODE" ]; then
    if ! should_mutate; then
      add_status updated ".agent-guidelines/rules source mode"
      RULE_SOURCE_DIR="$rules_path"
      return
    fi
    if [ "$STORED_RULE_SOURCE_MODE" = symlink ]; then
      remove_managed_symlink_safely "$rules_path" ||
        die "could not replace the managed rule-source symlink"
    else
      remove_managed_directory_safely "$rules_path" ||
        die "could not replace the managed rule-source snapshot"
    fi
  fi

  if [ "$RULE_SOURCE_MODE" = "symlink" ]; then
    if [ -L "$rules_path" ]; then
      local current
      current="$(readlink "$rules_path")"
      if [ "$current" = "$CANONICAL_RULES_DIR" ]; then
        add_status unchanged ".agent-guidelines/rules symlink"
      else
        die ".agent-guidelines/rules points to an unmanaged target: $current"
      fi
    elif [ -e "$rules_path" ]; then
      die ".agent-guidelines/rules exists and is not the managed symlink"
    else
      if should_mutate; then
        create_managed_symlink_safely "$rules_path" "$CANONICAL_RULES_DIR" ||
          die "could not create .agent-guidelines/rules symlink"
      fi
      add_status created ".agent-guidelines/rules symlink"
    fi
  fi

  if [ "$RULE_SOURCE_MODE" = "copy" ]; then
    if [ -d "$rules_path" ] &&
      diff -qr "$CANONICAL_RULES_DIR" "$rules_path" >/dev/null; then
      add_status unchanged ".agent-guidelines/rules snapshot"
    elif [ -e "$rules_path" ] || [ -L "$rules_path" ]; then
      die ".agent-guidelines/rules is not an exact managed snapshot"
    else
      if should_mutate; then
        copy_managed_directory_safely "$rules_path" "$CANONICAL_RULES_DIR" ||
          die "could not create .agent-guidelines/rules snapshot"
      fi
      add_status created ".agent-guidelines/rules snapshot"
    fi
  fi

  RULE_SOURCE_DIR="$rules_path"
  if [ ! -e "$RULE_SOURCE_DIR" ]; then
    RULE_SOURCE_DIR="$CANONICAL_RULES_DIR"
    if ! should_mutate; then
      add_status warning "preview is using canonical rules directly; install would create $rules_path"
    else
      add_status warning "using canonical rules directly because project rule source was unavailable"
    fi
  fi
}

contains_rule() {
  local needle="$1"
  shift
  local rule

  for rule in "$@"; do
    [ "$rule" = "$needle" ] && return 0
  done
  return 1
}

selected_rules_raw() {
  local rules=()
  local rule

  for rule in "${MINIMAL_RULES[@]}"; do
    rules+=("$rule")
  done

  if [ "$PROFILE" = "codebase" ] || [ "$PROFILE" = "released" ]; then
    for rule in "${CODEBASE_EXTRA_RULES[@]}"; do
      rules+=("$rule")
    done
  fi

  if [ "$PROFILE" = "released" ]; then
    for rule in "${RELEASED_EXTRA_RULES[@]}"; do
      rules+=("$rule")
    done
  fi

  case "$CHANGELOG_MODE" in
    date)
      rules+=("changelog-common" "changelog-date")
      ;;
    version)
      rules+=("changelog-common" "changelog-version" "versioning-semver" "backward-compatibility")
      ;;
  esac

  for rule in "${INCLUDE_RULES[@]}"; do
    rules+=("$rule")
  done

  for rule in "${rules[@]}"; do
    if contains_rule "$rule" "${EXCLUDE_RULES[@]}" &&
      ! is_mode_required_rule "$rule"; then
      continue
    fi
    printf '%s\n' "$rule"
  done | awk '!seen[$0]++'
}

is_mode_required_rule() {
  local rule="$1"

  case "$CHANGELOG_MODE:$rule" in
    date:changelog-common|date:changelog-date) return 0 ;;
    version:changelog-common|version:changelog-version|version:versioning-semver|version:backward-compatibility) return 0 ;;
  esac
  return 1
}

selected_rules_ordered() {
  local raw
  raw="$(selected_rules_raw)"

  local rule
  for rule in "${CANONICAL_RULE_ORDER[@]}"; do
    if printf '%s\n' "$raw" | grep -Fxq "$rule"; then
      printf '%s\n' "$rule"
    fi
  done

  {
    printf '%s\n' "$raw" |
      grep -Fvx -f <(printf '%s\n' "${CANONICAL_RULE_ORDER[@]}") || true
  } |
    sort
}

# Reports whether a global context file installed by setup.sh carries
# the managed rule block, meaning the always-tier rules and the full
# rule router are already loaded from there.
global_context_has_marker() {
  local path="$1"

  [ -f "$path" ] && grep -Fxq "$AGENT_GUIDELINES_MARKER_BEGIN" "$path"
}

# Resolves the context rules mode for one project file. In auto mode
# the project CLAUDE.md is trimmed when the Claude global context
# carries the managed block, and the project AGENTS.md is trimmed when
# any AGENTS-consuming global context does.
context_rules_mode_for() {
  local target="$1"

  if [ "$CONTEXT_RULES_MODE" != "auto" ]; then
    printf '%s' "$CONTEXT_RULES_MODE"
    return
  fi

  case "$target" in
    claude)
      if global_context_has_marker "${HOME}/.claude/CLAUDE.md"; then
        printf 'trimmed'
      else
        printf 'full'
      fi
      ;;
    agents)
      if global_context_has_marker "${HOME}/.config/opencode/AGENTS.md" ||
        global_context_has_marker "${HOME}/.pi/agent/AGENTS.md" ||
        global_context_has_marker "${HOME}/.codex/AGENTS.md"; then
        printf 'trimmed'
      else
        printf 'full'
      fi
      ;;
  esac
}

# Writes a trimmed managed block: the project's rule selection as a
# router table over .agent-guidelines/rules instead of inlined rule
# bodies. The always-tier rule text comes from the global context.
assemble_trimmed_rules_block() {
  local block_file="$1"
  local rules=()
  local rule

  while IFS= read -r rule; do
    [ -n "$rule" ] && rules+=("$rule")
  done < <(selected_rules_ordered)

  {
    printf '%s\n\n' "$AGENT_GUIDELINES_MARKER_BEGIN"
    printf '## Agent Guidelines Rule Selection\n\n'
    printf 'The always-loaded rules and the full rule router come from the\n'
    printf 'global context file installed by setup.sh. This project applies\n'
    printf 'the rules below; read a rule from its path when its trigger\n'
    printf 'matches the current task.\n\n'
    printf 'Profile: %s. Changelog mode: %s. Versioning mode: %s.\n\n' \
      "$PROFILE" "$CHANGELOG_MODE" "$(versioning_mode)"
    agent_guidelines_build_router_table \
      "$RULE_SOURCE_DIR" ".agent-guidelines/rules" "${rules[@]}"
    printf '\n%s\n' "$AGENT_GUIDELINES_MARKER_END"
  } > "$block_file"
}

assemble_rules_block() {
  local block_file="$1"
  local rules=()
  local rule
  local missing_log
  missing_log="$(mktemp)"

  while IFS= read -r rule; do
    [ -n "$rule" ] && rules+=("$rule")
  done < <(selected_rules_ordered)

  agent_guidelines_assemble_block \
    "$block_file" "$RULE_SOURCE_DIR" "${rules[@]}" 2> "$missing_log"

  while IFS= read -r line; do
    case "$line" in
      missing-rule:*)
        add_status warning "selected rule unavailable: ${line#missing-rule: }"
        ;;
      *)
        [ -n "$line" ] && printf '%s\n' "$line" >&2
        ;;
    esac
  done < "$missing_log"
  rm -f "$missing_log"
}

update_managed_block() {
  local target_file="$1"
  local block_file="$2"
  local label="$3"
  local status

  status="$(agent_guidelines_update_managed_block "$target_file" "$block_file")"
  add_status "$status" "$label"
}

preview_managed_block() {
  local target="$1"
  local label="$2"

  if [ ! -e "$target" ]; then
    add_status created "$label"
    return
  fi
  if grep -Fxq "$AGENT_GUIDELINES_MARKER_BEGIN" "$target" 2>/dev/null &&
    grep -Fxq "$AGENT_GUIDELINES_MARKER_END" "$target" 2>/dev/null; then
    add_status updated "$label"
  else
    add_status updated "$label (block would be appended)"
  fi
}

write_agent_file_preamble() {
  cat <<'EOF'
> **Generated file.** This file is assembled from the project's
> configured rules by `project-setup.sh`. Re-runs of
> `project-setup.sh` preserve everything outside the marker pair,
> including this note and any content you add to the
> Project-Specific Notes section below.

## Project-Specific Notes

_(Project-specific guidance for agents working in this repository.
Replace this line with your content; it is preserved across re-runs
of `project-setup.sh`.)_

EOF
}

prepend_preamble_if_created() {
  local target_file="$1"
  local preamble_file="$2"
  local status="$3"

  [ "$status" = "created" ] || return 0
  [ "$DRY_RUN" = true ] && return 0

  local temp_file
  temp_file="$(mktemp)"
  cat "$preamble_file" "$target_file" > "$temp_file"
  agent_guidelines_replace_file_safely "$target_file" "$temp_file"
  rm -f "$temp_file"
}

update_managed_block_with_preamble() {
  local target_file="$1"
  local block_file="$2"
  local preamble_file="$3"
  local label="$4"
  local status

  status="$(agent_guidelines_update_managed_block "$target_file" "$block_file")"
  prepend_preamble_if_created "$target_file" "$preamble_file" "$status"
  add_status "$status" "$label"
}

assemble_agent_files() {
  local full_block trimmed_block preamble_file
  local claude_mode agents_mode claude_block agents_block
  full_block=""
  trimmed_block=""
  preamble_file="$(mktemp)"
  write_agent_file_preamble > "$preamble_file"

  claude_mode="$(context_rules_mode_for claude)"
  agents_mode="$(context_rules_mode_for agents)"
  CLAUDE_CONTEXT_MODE="$claude_mode"
  AGENTS_CONTEXT_MODE="$agents_mode"

  if [ "$claude_mode" = "full" ] || [ "$agents_mode" = "full" ]; then
    full_block="$(mktemp)"
    assemble_rules_block "$full_block"
  fi
  if [ "$claude_mode" = "trimmed" ] || [ "$agents_mode" = "trimmed" ]; then
    trimmed_block="$(mktemp)"
    assemble_trimmed_rules_block "$trimmed_block"
  fi

  claude_block="$full_block"
  [ "$claude_mode" = "trimmed" ] && claude_block="$trimmed_block"
  agents_block="$full_block"
  [ "$agents_mode" = "trimmed" ] && agents_block="$trimmed_block"

  if should_mutate; then
    update_managed_block_with_preamble \
      "$TARGET_DIR/CLAUDE.md" "$claude_block" "$preamble_file" \
      "CLAUDE.md project rules ($claude_mode)"
    update_managed_block_with_preamble \
      "$TARGET_DIR/AGENTS.md" "$agents_block" "$preamble_file" \
      "AGENTS.md project rules ($agents_mode)"
  else
    preview_managed_block "$TARGET_DIR/CLAUDE.md" \
      "CLAUDE.md project rules ($claude_mode)"
    preview_managed_block "$TARGET_DIR/AGENTS.md" \
      "AGENTS.md project rules ($agents_mode)"
  fi

  rm -f "$preamble_file"
  [ -n "$full_block" ] && rm -f "$full_block"
  [ -n "$trimmed_block" ] && rm -f "$trimmed_block"
  return 0
}

skill_excluded() {
  local needle="$1"
  local skill
  for skill in "${EXCLUDE_SKILLS[@]}"; do
    [ "$skill" = "$needle" ] && return 0
  done
  return 1
}

selected_skills_filtered() {
  local skill
  for skill in "${INCLUDE_SKILLS[@]}"; do
    if ! skill_excluded "$skill"; then
      printf '%s\n' "$skill"
    fi
  done
}

install_project_skill_symlink() {
  local skill="$1"
  local target="$2"
  local source="$3"

  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ]; then
      add_status unchanged ".agents/skills/$skill"
    else
      die ".agents/skills/$skill points to an unmanaged target: $current"
    fi
  elif [ -e "$target" ]; then
    die ".agents/skills/$skill exists and is not the managed symlink"
  else
    if should_mutate; then
      create_managed_symlink_safely "$target" "$source" ||
        die "could not create .agents/skills/$skill symlink"
    fi
    add_status created ".agents/skills/$skill"
  fi
}

install_project_skill_copy() {
  local skill="$1"
  local target="$2"
  local source="$3"

  if [ -L "$target" ]; then
    die ".agents/skills/$skill exists as an unmanaged symlink"
  fi

  if [ -d "$target" ]; then
    if diff -qr "$source" "$target" >/dev/null; then
      add_status unchanged ".agents/skills/$skill"
    else
      die ".agents/skills/$skill is not an exact managed copy"
    fi
  elif [ -e "$target" ]; then
    die ".agents/skills/$skill exists and is not a managed copy"
  else
    if should_mutate; then
      copy_managed_directory_safely "$target" "$source" ||
        die "could not create .agents/skills/$skill copy"
    fi
    add_status created ".agents/skills/$skill"
  fi
}

validate_managed_directory() {
  local path="$1"
  local label="$2"

  if [ -L "$path" ]; then
    die "$label is a symlink: $path"
  fi
  if [ -e "$path" ] && [ ! -d "$path" ]; then
    die "$label is not a directory: $path"
  fi
}

preflight_rule_source_target() {
  local state_dir="$TARGET_DIR/.agent-guidelines"
  local rules_path="$state_dir/rules"
  local current

  agent_guidelines_assert_path_beneath \
    "$state_dir" "$TARGET_DIR" ".agent-guidelines" || exit 1
  agent_guidelines_assert_path_beneath \
    "$rules_path" "$TARGET_DIR" ".agent-guidelines/rules" || exit 1
  validate_managed_directory "$state_dir" ".agent-guidelines"

  if [ "$CONFIG_LOADED" = true ] &&
    [ "$STORED_RULE_SOURCE_MODE" != "$RULE_SOURCE_MODE" ]; then
    if [ "$STORED_RULE_SOURCE_MODE" = symlink ]; then
      [ -L "$rules_path" ] ||
        die ".agent-guidelines/rules is not the recorded managed symlink"
      current="$(readlink "$rules_path")"
      [ "$current" = "$CANONICAL_RULES_DIR" ] ||
        die ".agent-guidelines/rules points to an unmanaged target: $current"
    else
      [ -d "$rules_path" ] && [ ! -L "$rules_path" ] ||
        die ".agent-guidelines/rules is not the recorded managed snapshot"
      diff -qr "$CANONICAL_RULES_DIR" "$rules_path" >/dev/null ||
        die ".agent-guidelines/rules changed from its managed snapshot"
    fi
    return
  fi

  if [ "$RULE_SOURCE_MODE" = "symlink" ]; then
    if [ -L "$rules_path" ]; then
      current="$(readlink "$rules_path")"
      [ "$current" = "$CANONICAL_RULES_DIR" ] ||
        die ".agent-guidelines/rules points to an unmanaged target: $current"
    elif [ -e "$rules_path" ]; then
      die ".agent-guidelines/rules exists and is not the managed symlink"
    fi
    return
  fi

  if [ -L "$rules_path" ]; then
    die ".agent-guidelines/rules is an unmanaged symlink"
  fi
  if [ -e "$rules_path" ]; then
    [ -d "$rules_path" ] ||
      die ".agent-guidelines/rules is not a directory"
    diff -qr "$CANONICAL_RULES_DIR" "$rules_path" >/dev/null ||
      die ".agent-guidelines/rules is not an exact managed snapshot"
  fi
}

stored_skill_selected() {
  local skill="$1"

  array_contains "$skill" "${STORED_INCLUDE_SKILLS[@]}" || return 1
  ! array_contains "$skill" "${STORED_EXCLUDE_SKILLS[@]}"
}

desired_skill_selected() {
  local skill="$1"

  array_contains "$skill" "${INCLUDE_SKILLS[@]}" || return 1
  ! array_contains "$skill" "${EXCLUDE_SKILLS[@]}"
}

has_selected_skills() {
  local skill

  for skill in "${INCLUDE_SKILLS[@]}"; do
    desired_skill_selected "$skill" && return 0
  done
  return 1
}

preflight_deselected_skill_targets() {
  [ "$CONFIG_LOADED" = true ] || return 0

  local skill source target current
  for skill in "${STORED_INCLUDE_SKILLS[@]}"; do
    stored_skill_selected "$skill" || continue
    desired_skill_selected "$skill" && continue
    source="$CANONICAL_SKILLS_DIR/$skill"
    target="$TARGET_DIR/.agents/skills/$skill"
    agent_guidelines_assert_path_beneath \
      "$target" "$TARGET_DIR" ".agents/skills/$skill" || exit 1

    if [ "$STORED_SKILL_SOURCE_MODE" = symlink ]; then
      if [ -L "$target" ]; then
        current="$(readlink "$target")"
        [ "$current" = "$source" ] ||
          die ".agents/skills/$skill points to an unmanaged target: $current"
      elif [ -e "$target" ]; then
        die ".agents/skills/$skill is not the recorded managed symlink"
      fi
    else
      if [ -L "$target" ]; then
        die ".agents/skills/$skill is a symlink, not the recorded managed copy"
      elif [ -e "$target" ]; then
        [ -d "$source" ] || die "recorded skill source is missing: $source"
        [ -d "$target" ] ||
          die ".agents/skills/$skill is not the recorded managed copy"
        diff -qr "$source" "$target" >/dev/null ||
          die ".agents/skills/$skill changed from its recorded managed copy"
      fi
    fi
  done
}

preflight_skill_source_targets() {
  local agents_dir="$TARGET_DIR/.agents"
  local skills_dir="$agents_dir/skills"
  local skill source target current

  agent_guidelines_assert_path_beneath \
    "$agents_dir" "$TARGET_DIR" ".agents" || exit 1
  agent_guidelines_assert_path_beneath \
    "$skills_dir" "$TARGET_DIR" ".agents/skills" || exit 1
  validate_managed_directory "$agents_dir" ".agents"
  validate_managed_directory "$skills_dir" ".agents/skills"
  preflight_deselected_skill_targets

  for skill in "${INCLUDE_SKILLS[@]}"; do
    skill_excluded "$skill" && continue
    source="$CANONICAL_SKILLS_DIR/$skill"
    if [ ! -d "$source" ]; then
      if [ "$CONFIG_LOADED" = true ] && stored_skill_selected "$skill"; then
        die "recorded skill source is missing: $source"
      fi
      continue
    fi
    target="$skills_dir/$skill"
    agent_guidelines_assert_path_beneath \
      "$target" "$TARGET_DIR" ".agents/skills/$skill" || exit 1

    if [ "$CONFIG_LOADED" = true ] && stored_skill_selected "$skill" &&
      [ "$STORED_SKILL_SOURCE_MODE" != "$SKILL_SOURCE_MODE" ]; then
      if [ "$STORED_SKILL_SOURCE_MODE" = symlink ]; then
        [ -L "$target" ] ||
          die ".agents/skills/$skill is not the recorded managed symlink"
        current="$(readlink "$target")"
        [ "$current" = "$source" ] ||
          die ".agents/skills/$skill points to an unmanaged target: $current"
      else
        [ -d "$target" ] && [ ! -L "$target" ] ||
          die ".agents/skills/$skill is not the recorded managed copy"
        diff -qr "$source" "$target" >/dev/null ||
          die ".agents/skills/$skill changed from its recorded managed copy"
      fi
      continue
    fi

    if [ "$SKILL_SOURCE_MODE" = "symlink" ]; then
      if [ -L "$target" ]; then
        current="$(readlink "$target")"
        [ "$current" = "$source" ] ||
          die ".agents/skills/$skill points to an unmanaged target: $current"
      elif [ -e "$target" ]; then
        die ".agents/skills/$skill exists and is not the managed symlink"
      fi
    else
      if [ -L "$target" ]; then
        die ".agents/skills/$skill is an unmanaged symlink"
      elif [ -e "$target" ]; then
        [ -d "$target" ] ||
          die ".agents/skills/$skill is not a directory"
        diff -qr "$source" "$target" >/dev/null ||
          die ".agents/skills/$skill is not an exact managed copy"
      fi
    fi
  done
}

remove_deselected_project_skills() {
  [ "$CONFIG_LOADED" = true ] || return 0

  local skill target
  for skill in "${STORED_INCLUDE_SKILLS[@]}"; do
    stored_skill_selected "$skill" || continue
    desired_skill_selected "$skill" && continue
    target="$TARGET_DIR/.agents/skills/$skill"
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
      add_status unchanged ".agents/skills/$skill (already absent)"
      continue
    fi
    if should_mutate; then
      if [ "$STORED_SKILL_SOURCE_MODE" = symlink ]; then
        remove_managed_symlink_safely "$target" ||
          die "could not remove deselected .agents/skills/$skill symlink"
      else
        remove_managed_directory_safely "$target" ||
          die "could not remove deselected .agents/skills/$skill copy"
      fi
    fi
    add_status updated ".agents/skills/$skill removed"
  done
}

reconcile_selected_skill_source_modes() {
  [ "$CONFIG_LOADED" = true ] || return 0
  [ "$STORED_SKILL_SOURCE_MODE" != "$SKILL_SOURCE_MODE" ] || return 0

  local skill target
  for skill in "${STORED_INCLUDE_SKILLS[@]}"; do
    stored_skill_selected "$skill" || continue
    desired_skill_selected "$skill" || continue
    target="$TARGET_DIR/.agents/skills/$skill"
    if should_mutate; then
      if [ "$STORED_SKILL_SOURCE_MODE" = symlink ]; then
        remove_managed_symlink_safely "$target" ||
          die "could not replace .agents/skills/$skill symlink"
      else
        remove_managed_directory_safely "$target" ||
          die "could not replace .agents/skills/$skill copy"
      fi
    fi
    add_status updated ".agents/skills/$skill source mode"
  done
}

preflight_source_targets() {
  preflight_rule_source_target
  preflight_skill_source_targets
}

install_per_project_skills() {
  if [ "${#INCLUDE_SKILLS[@]}" -eq 0 ]; then
    return
  fi

  local skills_dir="$TARGET_DIR/.agents/skills"
  if should_mutate; then
    agent_guidelines_make_directory_safely "$skills_dir" ||
      die "could not create .agents/skills directory"
  fi

  local skill source target
  for skill in "${INCLUDE_SKILLS[@]}"; do
    if skill_excluded "$skill"; then
      add_status skipped ".agents/skills/$skill (excluded)"
      continue
    fi

    source="$CANONICAL_SKILLS_DIR/$skill"
    target="$skills_dir/$skill"

    if [ ! -d "$source" ]; then
      add_status warning "skill not found: $skill"
      continue
    fi

    if [ "$SKILL_SOURCE_MODE" = "symlink" ]; then
      install_project_skill_symlink "$skill" "$target" "$source"
    else
      install_project_skill_copy "$skill" "$target" "$source"
    fi
  done
}

write_local_config_content() {
  local identifier

  {
    printf 'schema=1\n'
    printf 'profile=%s\n' "$PROFILE"
    printf 'changelog=%s\n' "$CHANGELOG_MODE"
    printf 'context_rules=%s\n' "$CONTEXT_RULES_MODE"
    printf 'rules_source=%s\n' "$RULE_SOURCE_MODE"
    printf 'skills_source=%s\n' "$SKILL_SOURCE_MODE"
    [ -z "$DEFAULT_BRANCH" ] ||
      printf 'default_branch=%s\n' "$DEFAULT_BRANCH"
    for identifier in "${INCLUDE_RULES[@]}"; do
      printf 'include_rule=%s\n' "$identifier"
    done
    for identifier in "${EXCLUDE_RULES[@]}"; do
      printf 'exclude_rule=%s\n' "$identifier"
    done
    for identifier in "${INCLUDE_SKILLS[@]}"; do
      printf 'include_skill=%s\n' "$identifier"
    done
    for identifier in "${EXCLUDE_SKILLS[@]}"; do
      printf 'exclude_skill=%s\n' "$identifier"
    done
  }
}

write_local_config() {
  local config_path="$TARGET_DIR/.agent-guidelines/config"
  local temp_file
  local checksum
  local config_record
  temp_file="$(mktemp)"
  write_local_config_content > "$temp_file"
  config_record="$(ownership_record_path config)"

  if [ -e "$config_path" ] && cmp -s "$config_path" "$temp_file"; then
    add_status unchanged ".agent-guidelines/config"
  elif [ -f "$config_path" ] && [ -e "$config_record" ]; then
    if should_mutate; then
      checksum="$(sha256_file "$temp_file")"
      if ! agent_guidelines_replace_file_safely "$config_path" "$temp_file" ||
        ! replace_ownership_record config "sha256=$checksum"; then
        rm -f "$temp_file"
        die "config update failed"
      fi
    fi
    add_status updated ".agent-guidelines/config"
  elif [ -e "$config_path" ] || [ -L "$config_path" ]; then
    rm -f "$temp_file"
    die ".agent-guidelines/config differs from requested state"
  else
    if should_mutate; then
      checksum="$(sha256_file "$temp_file")"
      write_ownership_record config "sha256=$checksum" || {
        rm -f "$temp_file"
        die "could not record config ownership"
      }
      if ! agent_guidelines_replace_file_safely "$config_path" "$temp_file"; then
        rm -f "$temp_file"
        die "could not create .agent-guidelines/config"
      fi
    fi
    add_status created ".agent-guidelines/config"
  fi
  rm -f "$temp_file"
}

install_hook_snippet() {
  local hook_name="$1"
  local snippet_name="$2"
  local hook_path
  local snippet_path
  local temp_file

  hook_path="$(git_path "hooks/$hook_name")"
  snippet_path="$ASSET_DIR/hooks/$snippet_name"

  validate_hook_snippet_target "$hook_name" "$snippet_name" || return 1

  if [ ! -e "$hook_path" ]; then
    add_status created "$hook_name hook"
  fi

  local begin_marker
  begin_marker="$(sed -n '1p' "$snippet_path")"

  if [ -e "$hook_path" ] && grep -Fxq "$begin_marker" "$hook_path"; then
    if should_mutate; then
      replace_hook_block "$hook_path" "$snippet_path" "$begin_marker" "$hook_name $snippet_name"
    else
      add_status updated "$hook_name $snippet_name"
    fi
  else
    if should_mutate; then
      temp_file="$(mktemp)"
      if [ -e "$hook_path" ]; then
        cat "$hook_path" > "$temp_file"
      else
        printf '#!/bin/sh\n' > "$temp_file"
        chmod 644 "$temp_file"
      fi
      printf '\n' >> "$temp_file"
      cat "$snippet_path" >> "$temp_file"
      printf '\n' >> "$temp_file"
      agent_guidelines_validate_marker_pair \
        "$hook_path" "$begin_marker" \
        "$(sed -n '$p' "$snippet_path")" \
        "$hook_name $snippet_name" || {
        rm -f "$temp_file"
        return 1
      }
      if ! agent_guidelines_replace_file_safely "$hook_path" "$temp_file"; then
        rm -f "$temp_file"
        return 1
      fi
      rm -f "$temp_file"
    fi
    add_status updated "$hook_name $snippet_name"
  fi

  if should_mutate; then
    make_file_executable_safely "$hook_path" ||
      die "could not make hook executable: $hook_path"
  fi
}

replace_hook_block() {
  local hook_path="$1"
  local snippet_path="$2"
  local begin_marker="$3"
  local label="$4"
  local end_marker
  local temp_file

  end_marker="$(sed -n '$p' "$snippet_path")"
  agent_guidelines_validate_marker_pair \
    "$hook_path" "$begin_marker" "$end_marker" "$label" || return 1
  temp_file="$(mktemp)"

  awk -v begin="$begin_marker" -v end="$end_marker" -v snippet="$snippet_path" '
    $0 == begin {
      while ((getline line < snippet) > 0) print line
      in_block = 1
      next
    }
    $0 == end {
      in_block = 0
      next
    }
    !in_block { print }
  ' "$hook_path" > "$temp_file"

  if cmp -s "$hook_path" "$temp_file"; then
    add_status unchanged "$label"
  else
    agent_guidelines_validate_marker_pair \
      "$hook_path" "$begin_marker" "$end_marker" "$label" || {
      rm -f "$temp_file"
      return 1
    }
    if ! agent_guidelines_replace_file_safely "$hook_path" "$temp_file"; then
      rm -f "$temp_file"
      return 1
    fi
    add_status updated "$label"
  fi
  rm -f "$temp_file"
}

install_hooks() {
  if ! target_has_git_repo; then
    add_status skipped "git hooks (target has no git repo)"
    return
  fi
  validate_all_hook_snippet_targets || return 1
  install_hook_snippet pre-commit pre-commit-main-branch
  install_hook_snippet pre-commit pre-commit-attribution
  install_hook_snippet pre-commit pre-commit-banned-phrases
  install_hook_snippet commit-msg commit-msg-attribution
  install_hook_snippet commit-msg commit-msg-banned-phrases
  install_hook_snippet commit-msg commit-msg-conventional
  install_hook_snippet pre-push pre-push-branch-name
}

# Exclude ownership records written only for lines created by this script.
MANAGED_EXCLUDE_RECORDS=(
  "claude|CLAUDE.md"
  "claude-local|CLAUDE.local.md"
  "agents|AGENTS.md"
  "claude-dir|.claude/"
  "codex-dir|.codex/"
  "config|.agent-guidelines/config"
  "rules|.agent-guidelines/rules"
  "opencode|opencode.json"
  "mcp|.mcp.json"
  "skills|.agents/skills/"
)

# Managed hook snippets the removal flow strips; mirrors
# install_hooks.
MANAGED_HOOK_SNIPPETS=(
  "pre-commit|pre-commit-main-branch"
  "pre-commit|pre-commit-attribution"
  "pre-commit|pre-commit-banned-phrases"
  "commit-msg|commit-msg-attribution"
  "commit-msg|commit-msg-banned-phrases"
  "commit-msg|commit-msg-conventional"
  "pre-push|pre-push-branch-name"
)

validate_hook_snippet_target() {
  local hook_name="$1"
  local snippet_name="$2"
  local hook_path snippet_path begin_marker end_marker

  hook_path="$(git_path "hooks/$hook_name")"
  snippet_path="$ASSET_DIR/hooks/$snippet_name"
  assert_local_git_path "$hook_path" "$hook_name hook" ||
    die "managed hook path escapes the repository Git directory: $hook_path"
  begin_marker="$(sed -n '1p' "$snippet_path")"
  end_marker="$(sed -n '$p' "$snippet_path")"

  agent_guidelines_validate_marker_pair \
    "$hook_path" "$begin_marker" "$end_marker" \
    "$hook_name $snippet_name"
}

validate_all_hook_snippet_targets() {
  local pair hook_name snippet_name

  for pair in "${MANAGED_HOOK_SNIPPETS[@]}"; do
    hook_name="${pair%%|*}"
    snippet_name="${pair##*|}"
    validate_hook_snippet_target "$hook_name" "$snippet_name" || return 1
  done
}

validate_ownership_record() {
  local name="$1"
  local expected="$2"
  local path

  path="$(ownership_record_path "$name")"
  if [ -L "$path" ] || [ ! -f "$path" ] ||
    [ "$(wc -l < "$path")" -ne 1 ] ||
    ! grep -Fxq "$expected" "$path"; then
    die "invalid ownership record: $path"
  fi
}

ownership_record_known() {
  local name="$1"
  local pair key

  case "$name" in
    commit-template|config) return 0 ;;
  esac
  for pair in "${MANAGED_EXCLUDE_RECORDS[@]}"; do
    key="${pair%%|*}"
    [ "$name" = "$(exclude_record_name "$key")" ] && return 0
  done
  return 1
}

validate_ownership_state() {
  target_has_git_repo || return 0

  local state_dir
  local record_path
  local record_name
  local current
  local expected_hash
  local pair key line count
  local exclude_file

  state_dir="$(ownership_dir)"
  validate_managed_directory "$state_dir" "ownership state"
  [ -d "$state_dir" ] || return 0

  while IFS= read -r -d '' record_path; do
    record_name="$(basename "$record_path")"
    ownership_record_known "$record_name" ||
      die "unknown ownership record: $record_path"
  done < <(find "$state_dir" -mindepth 1 -maxdepth 1 -print0)

  record_path="$(ownership_record_path commit-template)"
  if [ -e "$record_path" ] || [ -L "$record_path" ]; then
    validate_ownership_record commit-template 'created=.gittemplate'
    current="$(git -C "$TARGET_DIR" config --local --get commit.template || true)"
    [ "$current" = ".gittemplate" ] ||
      die "owned commit.template no longer matches .gittemplate"
  fi

  record_path="$(ownership_record_path config)"
  if [ -e "$record_path" ] || [ -L "$record_path" ]; then
    if [ -L "$record_path" ] || [ ! -f "$record_path" ] ||
      [ "$(wc -l < "$record_path")" -ne 1 ] ||
      ! grep -Eq '^sha256=[0-9a-f]{64}$' "$record_path"; then
      die "invalid config ownership record: $record_path"
    fi
    expected_hash="$(sed 's/^sha256=//' "$record_path")"
    if [ -L "$TARGET_DIR/.agent-guidelines/config" ] ||
      [ ! -f "$TARGET_DIR/.agent-guidelines/config" ] ||
      [ "$(sha256_file "$TARGET_DIR/.agent-guidelines/config")" != "$expected_hash" ]; then
      die "owned config no longer matches its recorded content"
    fi
  fi

  exclude_file="$(git_path info/exclude)"
  for pair in "${MANAGED_EXCLUDE_RECORDS[@]}"; do
    key="${pair%%|*}"
    line="${pair##*|}"
    record_name="$(exclude_record_name "$key")"
    record_path="$(ownership_record_path "$record_name")"
    if [ -e "$record_path" ] || [ -L "$record_path" ]; then
      validate_ownership_record "$record_name" "line=$line"
      if [ -L "$exclude_file" ] || [ ! -f "$exclude_file" ]; then
        die "owned exclude line has no regular exclude file: $line"
      fi
      count="$(grep -Fxc "$line" "$exclude_file" || true)"
      [ "$count" -eq 1 ] ||
        die "owned exclude line no longer has one exact match: $line"
    fi
  done
}

validate_regular_or_missing() {
  local path="$1"
  local label="$2"
  local path_type

  agent_guidelines_assert_path_beneath "$path" "$TARGET_DIR" "$label" ||
    exit 1
  path_type="$(agent_guidelines_path_type "$path")"
  case "$path_type" in
    missing|regular) ;;
    *) die "$label must be a regular file or missing: $path ($path_type)" ;;
  esac
}

preflight_project_files() {
  validate_regular_or_missing "$TARGET_DIR/.gittemplate" ".gittemplate"
  validate_regular_or_missing "$TARGET_DIR/.gitignore" ".gitignore"
  validate_regular_or_missing "$TARGET_DIR/README.md" "README.md"
  if [ "$CHANGELOG_MODE" != none ]; then
    validate_regular_or_missing "$TARGET_DIR/CHANGELOG.md" "CHANGELOG.md"
  fi
  validate_regular_or_missing \
    "$TARGET_DIR/.agent-guidelines/config" ".agent-guidelines/config"

  local desired_config
  local config_owned=false
  desired_config="$(mktemp)"
  write_local_config_content > "$desired_config"
  if target_has_git_repo && [ -e "$(ownership_record_path config)" ]; then
    config_owned=true
  fi
  if [ -e "$TARGET_DIR/.agent-guidelines/config" ] &&
    ! cmp -s "$TARGET_DIR/.agent-guidelines/config" "$desired_config" &&
    [ "$config_owned" = false ]; then
      rm -f "$desired_config"
      die ".agent-guidelines/config differs from requested state"
  fi
  rm -f "$desired_config"

  if target_has_git_repo; then
    local current_template config_file exclude_file exclude_type
    exclude_file="$(git_path info/exclude)"
    config_file="$(git_path config)"
    assert_local_git_path "$exclude_file" "git info/exclude" || exit 1
    assert_local_git_path "$config_file" "git config" || exit 1
    exclude_type="$(agent_guidelines_path_type "$exclude_file")"
    case "$exclude_type" in
      missing|regular) ;;
      *) die "git info/exclude is not a regular file: $exclude_file" ;;
    esac

    current_template="$(git -C "$TARGET_DIR" config --local \
      --get commit.template || true)"
    case "$current_template" in
      ""|.gittemplate) ;;
      *) die "git commit.template is user-managed: $current_template" ;;
    esac
  fi
}

preflight_managed_targets() {
  agent_guidelines_assert_path_beneath \
    "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR" "CLAUDE.md" || return 1
  agent_guidelines_assert_path_beneath \
    "$TARGET_DIR/AGENTS.md" "$TARGET_DIR" "AGENTS.md" || return 1
  agent_guidelines_validate_managed_block_file \
    "$TARGET_DIR/CLAUDE.md" || return 1
  agent_guidelines_validate_managed_block_file \
    "$TARGET_DIR/AGENTS.md" || return 1

  if target_has_git_repo; then
    validate_ownership_state
    validate_all_hook_snippet_targets || return 1
  fi
}

remove_hook_snippet() {
  local hook_name="$1"
  local snippet_name="$2"
  local hook_path snippet_path begin_marker end_marker temp_file

  hook_path="$(git_path "hooks/$hook_name")"
  snippet_path="$ASSET_DIR/hooks/$snippet_name"

  if [ ! -e "$hook_path" ]; then
    add_status unchanged "$hook_name $snippet_name (not installed)"
    return 0
  fi

  begin_marker="$(sed -n '1p' "$snippet_path")"
  end_marker="$(sed -n '$p' "$snippet_path")"

  agent_guidelines_validate_marker_pair \
    "$hook_path" "$begin_marker" "$end_marker" \
    "$hook_name $snippet_name" || return 1

  if ! grep -Fxq "$begin_marker" "$hook_path"; then
    add_status unchanged "$hook_name $snippet_name (not installed)"
    return 0
  fi

  if should_mutate; then
    temp_file="$(mktemp)"
    awk -v begin="$begin_marker" -v end="$end_marker" '
      $0 == begin { in_block = 1; next }
      $0 == end { in_block = 0; next }
      !in_block { print }
    ' "$hook_path" > "$temp_file"
    agent_guidelines_validate_marker_pair \
      "$hook_path" "$begin_marker" "$end_marker" \
      "$hook_name $snippet_name" || {
      rm -f "$temp_file"
      return 1
    }
    if ! agent_guidelines_replace_file_safely "$hook_path" "$temp_file"; then
      rm -f "$temp_file"
      return 1
    fi
    rm -f "$temp_file"
  fi
  add_status updated "$hook_name $snippet_name removed"
}

# Deletes a hook file that holds nothing but a shebang and blank
# lines after the managed snippets are gone; foreign content keeps
# the file in place.
prune_empty_hook() {
  local hook_name="$1"
  local hook_path

  hook_path="$(git_path "hooks/$hook_name")"
  [ -e "$hook_path" ] || return 0

  if grep -Evq '^#!|^[[:space:]]*$' "$hook_path"; then
    return 0
  fi

  if should_mutate; then
    agent_guidelines_remove_file_safely "$hook_path" || return 1
  fi
  add_status updated "$hook_name hook removed (only managed content)"
}

remove_managed_excludes() {
  local exclude_file managed_list temp_file pair key line record_name
  local record_path
  local has_owned=false

  if ! target_has_git_repo; then
    add_status skipped "git info/exclude (target has no git repo)"
    return 0
  fi

  exclude_file="$(git_path info/exclude)"
  managed_list="$(mktemp)"
  for pair in "${MANAGED_EXCLUDE_RECORDS[@]}"; do
    key="${pair%%|*}"
    line="${pair##*|}"
    record_name="$(exclude_record_name "$key")"
    record_path="$(ownership_record_path "$record_name")"
    if [ -e "$record_path" ]; then
      printf '%s\n' "$line" >> "$managed_list"
      has_owned=true
    fi
  done

  if [ "$has_owned" = false ]; then
    rm -f "$managed_list"
    add_status skipped "git info/exclude has no owned lines"
    return 0
  fi

  if ! should_mutate; then
    rm -f "$managed_list"
    add_status updated "owned exclude lines would be removed"
    return 0
  fi

  temp_file="$(mktemp)"
  grep -Fvxf "$managed_list" "$exclude_file" > "$temp_file" || true

  if cmp -s "$exclude_file" "$temp_file"; then
    rm -f "$managed_list" "$temp_file"
    die "owned exclude records did not match removable lines"
  else
    agent_guidelines_replace_file_safely "$exclude_file" "$temp_file" || {
      rm -f "$managed_list" "$temp_file"
      die "could not remove owned exclude lines"
    }
    for pair in "${MANAGED_EXCLUDE_RECORDS[@]}"; do
      key="${pair%%|*}"
      record_name="$(exclude_record_name "$key")"
      record_path="$(ownership_record_path "$record_name")"
      if [ -e "$record_path" ]; then
        agent_guidelines_remove_file_safely "$record_path" ||
          die "could not remove exclude ownership record: $record_path"
      fi
    done
    add_status updated "owned exclude lines removed"
  fi
  rm -f "$managed_list" "$temp_file"
}

remove_commit_template_config() {
  if ! target_has_git_repo; then
    return 0
  fi

  local current record_path
  record_path="$(ownership_record_path commit-template)"
  if [ ! -e "$record_path" ]; then
    add_status skipped "git commit.template has no ownership record"
    return 0
  fi

  current="$(git -C "$TARGET_DIR" config --local --get commit.template || true)"
  if [ "$current" != ".gittemplate" ]; then
    die "owned commit.template changed before removal"
  fi

  if should_mutate; then
    mutate_local_git_config --unset commit.template ||
      die "could not unset git commit.template"
    agent_guidelines_remove_file_safely "$record_path" ||
      die "could not remove commit.template ownership record"
  fi
  add_status updated "git commit.template unset"
}

# Strips the managed block from one context file; deletes the file
# when nothing but the generated preamble remains.
remove_context_file_block() {
  local target_file="$1"
  local label="$2"
  local preamble_file status

  if [ ! -e "$target_file" ]; then
    add_status unchanged "$label (absent)"
    return 0
  fi

  if ! grep -Fxq "$AGENT_GUIDELINES_MARKER_BEGIN" "$target_file"; then
    add_status skipped "$label has no managed block"
    return 0
  fi

  if ! should_mutate; then
    add_status updated "$label managed block would be removed"
    return 0
  fi

  status="$(agent_guidelines_remove_managed_block "$target_file")"
  if [ "$status" = "cleared" ]; then
    preamble_file="$(mktemp)"
    write_agent_file_preamble > "$preamble_file"
    if cmp -s <(sed -e 's/[[:space:]]*$//' "$target_file" |
        grep -v '^$') \
      <(sed -e 's/[[:space:]]*$//' "$preamble_file" | grep -v '^$'); then
      agent_guidelines_remove_file_safely "$target_file"
      status="removed"
    fi
    rm -f "$preamble_file"
  fi
  add_status updated "$label managed block $status"
}

remove_rule_source_state() {
  local state_dir="$TARGET_DIR/.agent-guidelines"
  local rules_path="$state_dir/rules"
  local config_path="$state_dir/config"

  if [ -L "$rules_path" ]; then
    if [ "$(readlink "$rules_path")" = "$CANONICAL_RULES_DIR" ]; then
      if should_mutate; then
        remove_managed_symlink_safely "$rules_path" ||
          die "could not remove .agent-guidelines/rules symlink"
      fi
      add_status updated ".agent-guidelines/rules symlink removed"
    else
      add_status skipped ".agent-guidelines/rules is an unowned symlink"
    fi
  elif [ -d "$rules_path" ]; then
    add_status skipped ".agent-guidelines/rules snapshot left in place"
  fi

  local config_record
  config_record="$(ownership_record_path config)"
  if [ -e "$config_record" ]; then
    if should_mutate; then
      agent_guidelines_remove_file_safely "$config_path" ||
        die "could not remove .agent-guidelines/config"
      agent_guidelines_remove_file_safely "$config_record" ||
        die "could not remove config ownership record"
    fi
    add_status updated ".agent-guidelines/config removed"
  elif [ -e "$config_path" ] || [ -L "$config_path" ]; then
    add_status skipped ".agent-guidelines/config has no ownership record"
  fi

}

remove_project_skill_links() {
  local skills_dir="$TARGET_DIR/.agents/skills"
  local entry link_target expected_target

  [ -d "$skills_dir" ] || return 0

  for entry in "$skills_dir"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    if [ -L "$entry" ]; then
      link_target="$(readlink "$entry")"
      expected_target="$CANONICAL_SKILLS_DIR/$(basename "$entry")"
      if [ "$link_target" = "$expected_target" ]; then
        if should_mutate; then
          remove_managed_symlink_safely "$entry" ||
            die "could not remove .agents/skills/$(basename "$entry") link"
        fi
        add_status updated ".agents/skills/$(basename "$entry") link removed"
      else
        add_status skipped ".agents/skills/$(basename "$entry") is unowned"
      fi
    else
      add_status skipped ".agents/skills/$(basename "$entry") is a copy"
    fi
  done

}

cleanup_ownership_state() {
  target_has_git_repo || return 0
  if should_mutate; then
    rmdir "$(ownership_dir)" 2>/dev/null || true
    rmdir "$(dirname "$(ownership_dir)")" 2>/dev/null || true
    rmdir "$TARGET_DIR/.agent-guidelines" 2>/dev/null || true
    rmdir "$TARGET_DIR/.agents/skills" "$TARGET_DIR/.agents" 2>/dev/null || true
  fi
}

print_remove_summary() {
  printf '\nProject removal summary\n'
  if [ "$DRY_RUN" = true ]; then
    printf 'Mode: dry-run (no files modified)\n'
  fi
  printf 'Repository: %s\n' "$TARGET_DIR"

  local updated_label="Removed or updated:"
  if [ "$DRY_RUN" = true ]; then
    updated_label="Would remove or update:"
  fi
  print_list "$updated_label" "${UPDATED[@]}"
  print_list "Unchanged:" "${UNCHANGED[@]}"
  print_list "Skipped:" "${SKIPPED[@]}"
  print_list "Warnings:" "${WARNINGS[@]}"
}

run_remove() {
  [ -d "$TARGET_DIR" ] || die "target directory does not exist: $TARGET_DIR"
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd -P)"

  validate_target_worktree_root
  preflight_managed_targets || return 1
  if should_mutate; then
    agent_guidelines_transaction_begin
  fi

  local pair hook_name snippet_name
  if target_has_git_repo; then
    for pair in "${MANAGED_HOOK_SNIPPETS[@]}"; do
      hook_name="${pair%%|*}"
      snippet_name="${pair##*|}"
      remove_hook_snippet "$hook_name" "$snippet_name"
    done
    for hook_name in pre-commit commit-msg pre-push; do
      prune_empty_hook "$hook_name"
    done
  else
    add_status skipped "git hooks (target has no git repo)"
  fi

  remove_managed_excludes
  remove_commit_template_config
  remove_context_file_block "$TARGET_DIR/CLAUDE.md" "CLAUDE.md"
  remove_context_file_block "$TARGET_DIR/AGENTS.md" "AGENTS.md"
  remove_rule_source_state
  remove_project_skill_links

  if should_mutate; then
    agent_guidelines_transaction_commit
    cleanup_ownership_state
  fi
  print_remove_summary
}

create_initial_commit_if_needed() {
  if ! target_has_git_repo; then
    # Dry-run may report a planned init without creating .git/, in
    # which case the initial commit is planned but cannot be staged.
    if [ "$REPO_CREATED" = true ] && ! should_mutate; then
      add_status created "initial commit (would be created by install)"
      return
    fi
    add_status skipped "initial commit because target has no git repo"
    return
  fi

  if git -C "$TARGET_DIR" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
    add_status skipped "initial commit because repository already has commits"
    return
  fi

  if [ "$REPO_CREATED" != true ]; then
    add_status skipped \
      "initial commit because setup did not initialize the repository"
    return
  fi

  if ! should_mutate; then
    add_status created "initial commit (would be created by install)"
    return
  fi

  local paths=(".gittemplate" ".gitignore" "README.md")
  if [ "$CHANGELOG_MODE" != "none" ]; then
    paths+=("CHANGELOG.md")
  fi
  if [ "$RULE_SOURCE_MODE" = "copy" ]; then
    paths+=(".agent-guidelines/rules")
  fi
  if [ "$SKILL_SOURCE_MODE" = "copy" ] &&
    [ "${#INCLUDE_SKILLS[@]}" -gt 0 ] &&
    [ -d "$TARGET_DIR/.agents/skills" ]; then
    paths+=(".agents/skills")
  fi

  local path
  for path in "${paths[@]}"; do
    [ -e "$TARGET_DIR/$path" ] && git -C "$TARGET_DIR" add "$path"
  done

  if git -C "$TARGET_DIR" diff --cached --quiet; then
    add_status skipped "initial commit because no project files were staged"
    return
  fi

  GIT_AUTHOR_NAME="$GIT_USER_NAME" \
    GIT_AUTHOR_EMAIL="$GIT_USER_EMAIL" \
    GIT_COMMITTER_NAME="$GIT_USER_NAME" \
    GIT_COMMITTER_EMAIL="$GIT_USER_EMAIL" \
    git -C "$TARGET_DIR" commit -m "chore: initialize repository" >/dev/null
  add_status created "initial commit"
}

print_list() {
  local title="$1"
  shift

  printf '%s\n' "$title"
  if [ "$#" -eq 0 ]; then
    printf '  none\n'
    return
  fi

  local item
  for item in "$@"; do
    printf '  - %s\n' "$item"
  done
}

print_summary() {
  local branch
  branch="$(git -C "$TARGET_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached')"

  printf '\nProject setup summary\n'
  if [ "$DRY_RUN" = true ]; then
    printf 'Mode: dry-run (no files modified)\n'
  fi
  printf 'Repository: %s\n' "$TARGET_DIR"
  printf 'Branch: %s\n' "$branch"
  printf 'Default branch: %s\n' "$DEFAULT_BRANCH"
  printf 'Git user: %s <%s>\n' "$GIT_USER_NAME" "$GIT_USER_EMAIL"
  printf 'Profile: %s\n' "$PROFILE"
  printf 'Changelog mode: %s\n' "$CHANGELOG_MODE"
  printf 'Versioning mode: %s\n' "$(versioning_mode)"
  printf 'Context rules mode: %s (CLAUDE.md %s, AGENTS.md %s)\n' \
    "$CONTEXT_RULES_MODE" \
    "${CLAUDE_CONTEXT_MODE:-unresolved}" "${AGENTS_CONTEXT_MODE:-unresolved}"
  printf 'Rule source mode: %s\n' "$RULE_SOURCE_MODE"
  printf 'Skill source mode: %s\n\n' "$SKILL_SOURCE_MODE"

  local included_rules=()
  local r
  while IFS= read -r r; do
    [ -n "$r" ] && included_rules+=("$r")
  done < <(selected_rules_ordered)

  local included_skills=()
  local s
  while IFS= read -r s; do
    [ -n "$s" ] && included_skills+=("$s")
  done < <(selected_skills_filtered)

  print_list "Rules included (${#included_rules[@]}):" "${included_rules[@]}"
  print_list "Skills included (${#included_skills[@]}):" "${included_skills[@]}"

  local created_label="Created:"
  local updated_label="Updated:"
  if [ "$DRY_RUN" = true ]; then
    created_label="Would create:"
    updated_label="Would update:"
  fi

  print_list "$created_label" "${CREATED[@]}"
  print_list "$updated_label" "${UPDATED[@]}"
  print_list "Unchanged:" "${UNCHANGED[@]}"
  print_list "Skipped:" "${SKIPPED[@]}"
  print_list "Warnings:" "${WARNINGS[@]}"
}

main() {
  parse_args "$@"
  validate_git_environment

  if [ "$MODE" = "remove" ]; then
    run_remove
    return 0
  fi

  resolve_target
  validate_target_worktree_root
  load_local_config
  require_git_identity
  preflight_existing_unborn_index
  resolve_default_branch
  infer_profile
  infer_changelog_mode
  preflight_managed_targets
  preflight_source_targets
  preflight_project_files
  if should_mutate; then
    agent_guidelines_transaction_begin
  fi
  init_git_if_needed

  write_file_if_missing "$TARGET_DIR/.gittemplate" "$ASSET_DIR/gittemplate" ".gittemplate"
  write_file_if_missing "$TARGET_DIR/.gitignore" "$ASSET_DIR/gitignore-minimal" ".gitignore"
  write_readme_if_missing
  if [ "$CHANGELOG_MODE" != "none" ]; then
    write_file_if_missing "$TARGET_DIR/CHANGELOG.md" "$ASSET_DIR/changelog-base.md" "CHANGELOG.md"
  else
    add_status skipped "CHANGELOG.md because changelog mode is none"
  fi

  configure_commit_template
  configure_local_excludes
  configure_rule_source
  assemble_agent_files
  remove_deselected_project_skills
  reconcile_selected_skill_source_modes
  install_per_project_skills
  create_initial_commit_if_needed
  install_hooks
  write_local_config
  finalize_staged_git_repository
  if should_mutate; then
    agent_guidelines_transaction_commit
  fi
  print_summary
}

main "$@"
