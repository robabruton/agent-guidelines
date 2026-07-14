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
TARGET_DIR="."
DRY_RUN=false
INCLUDE_RULES=()
EXCLUDE_RULES=()
INCLUDE_SKILLS=()
EXCLUDE_SKILLS=()

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
  --remove        remove the managed hook snippets, exclude lines,
                  context blocks, and .agent-guidelines state this
                  script installed, leaving project artifacts and
                  user content in place
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

  for identifier in "${INCLUDE_RULES[@]}" "${EXCLUDE_RULES[@]}"; do
    validate_catalog_id rule "$identifier"
  done
  for identifier in "${INCLUDE_SKILLS[@]}" "${EXCLUDE_SKILLS[@]}"; do
    validate_catalog_id skill "$identifier"
  done
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --profile)
        [ "$#" -ge 2 ] || die "--profile requires a value"
        PROFILE="$2"
        shift 2
        ;;
      --changelog)
        [ "$#" -ge 2 ] || die "--changelog requires a value"
        CHANGELOG_MODE="$2"
        shift 2
        ;;
      --context-rules)
        [ "$#" -ge 2 ] || die "--context-rules requires a value"
        CONTEXT_RULES_MODE="$2"
        shift 2
        ;;
      --rules-source)
        [ "$#" -ge 2 ] || die "--rules-source requires a value"
        RULE_SOURCE_MODE="$2"
        shift 2
        ;;
      --skills-source)
        [ "$#" -ge 2 ] || die "--skills-source requires a value"
        SKILL_SOURCE_MODE="$2"
        shift 2
        ;;
      --include-rule)
        [ "$#" -ge 2 ] || die "--include-rule requires a value"
        INCLUDE_RULES+=("$2")
        shift 2
        ;;
      --exclude-rule)
        [ "$#" -ge 2 ] || die "--exclude-rule requires a value"
        EXCLUDE_RULES+=("$2")
        shift 2
        ;;
      --include-skill)
        [ "$#" -ge 2 ] || die "--include-skill requires a value"
        INCLUDE_SKILLS+=("$2")
        shift 2
        ;;
      --exclude-skill)
        [ "$#" -ge 2 ] || die "--exclude-skill requires a value"
        EXCLUDE_SKILLS+=("$2")
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
  if [ -z "$SKILL_SOURCE_MODE" ]; then
    SKILL_SOURCE_MODE="$RULE_SOURCE_MODE"
  fi
  case "$SKILL_SOURCE_MODE" in symlink|copy) ;; *) die "invalid skills source mode: $SKILL_SOURCE_MODE" ;; esac
  validate_catalog_ids
}

resolve_target() {
  if should_mutate; then
    mkdir -p "$TARGET_DIR"
  elif [ ! -d "$TARGET_DIR" ]; then
    die "--dry-run target directory does not exist: $TARGET_DIR"
  fi
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd -P)"
}

require_git_identity() {
  command -v git >/dev/null 2>&1 || die "git is required"

  local name
  local email
  name="$(git config --get user.name || true)"
  email="$(git config --get user.email || true)"

  if [ -z "$name" ] || [ -z "$email" ]; then
    cat >&2 <<'EOF'
git user.name and user.email must be configured before setup can continue.

Run:
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
EOF
    exit 1
  fi
}

init_git_if_needed() {
  if target_has_git_repo; then
    add_status unchanged "git repository already exists"
    REPO_CREATED=false
    return
  fi

  if should_mutate; then
    git -C "$TARGET_DIR" init --initial-branch=main >/dev/null
  fi
  add_status created "git repository"
  REPO_CREATED=true
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
    mkdir -p "$(dirname "$path")"
    cp "$source" "$path"
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
    {
      printf '# %s\n\n' "$(basename "$TARGET_DIR")"
    } > "$path"
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
      git -C "$TARGET_DIR" config --local commit.template .gittemplate
      if ! write_ownership_record \
        commit-template 'created=.gittemplate'; then
        git -C "$TARGET_DIR" config --local --unset commit.template || true
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

sha256_file() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{ print $1 }'
  else
    shasum -a 256 "$path" | awk '{ print $1 }'
  fi
}

ownership_dir() {
  git_path agent-guidelines/ownership-v1
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

  mkdir -p "$(dirname "$path")"
  if ! agent_guidelines_atomic_replace_file "$path" "$prepared"; then
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
  agent_guidelines_atomic_replace_file "$path" "$prepared"
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
    if ! agent_guidelines_atomic_replace_file "$file" "$prepared"; then
      rm -f "$prepared" "$(ownership_record_path "$record_name")"
      die "could not update $file"
    fi
    rm -f "$prepared"
  fi
  add_status updated "$label"
}

configure_local_excludes() {
  if ! target_has_git_repo; then
    add_status skipped "git info/exclude (target has no git repo)"
    return
  fi

  local exclude_file local_file key
  exclude_file="$(git_path info/exclude)"
  if should_mutate; then
    mkdir -p "$(dirname "$exclude_file")"
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
    mkdir -p "$state_dir"
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
        ln -s "$CANONICAL_RULES_DIR" "$rules_path"
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
        cp -a "$CANONICAL_RULES_DIR" "$rules_path"
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
  mv "$temp_file" "$target_file"
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
      ln -s "$source" "$target"
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
      cp -aR "$source" "$target"
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

  for skill in "${INCLUDE_SKILLS[@]}"; do
    skill_excluded "$skill" && continue
    source="$CANONICAL_SKILLS_DIR/$skill"
    [ -d "$source" ] || continue
    target="$skills_dir/$skill"
    agent_guidelines_assert_path_beneath \
      "$target" "$TARGET_DIR" ".agents/skills/$skill" || exit 1

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
    mkdir -p "$skills_dir"
  fi

  if [ "$SKILL_SOURCE_MODE" = "symlink" ] && target_has_git_repo; then
    local exclude_file
    exclude_file="$(git_path info/exclude)"
    append_missing_line "$exclude_file" ".agents/skills/" \
      "exclude .agents/skills/" skills
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
  {
    printf 'profile=%s\n' "$PROFILE"
    printf 'changelog=%s\n' "$CHANGELOG_MODE"
    printf 'versioning=%s\n' "$(versioning_mode)"
    printf 'context_rules=%s\n' "$CONTEXT_RULES_MODE"
    printf 'rules_source=%s\n' "$RULE_SOURCE_MODE"
    printf 'skills_source=%s\n' "$SKILL_SOURCE_MODE"
    printf 'include_rules=%s\n' "${INCLUDE_RULES[*]:-}"
    printf 'exclude_rules=%s\n' "${EXCLUDE_RULES[*]:-}"
    printf 'include_skills=%s\n' "${INCLUDE_SKILLS[*]:-}"
    printf 'exclude_skills=%s\n' "${EXCLUDE_SKILLS[*]:-}"
  }
}

write_local_config() {
  local config_path="$TARGET_DIR/.agent-guidelines/config"
  local temp_file
  local checksum
  local config_record
  local rollback_dir
  local rollback_file
  temp_file="$(mktemp)"
  write_local_config_content > "$temp_file"
  config_record="$(ownership_record_path config)"

  if [ -e "$config_path" ] && cmp -s "$config_path" "$temp_file"; then
    add_status unchanged ".agent-guidelines/config"
  elif [ -f "$config_path" ] && [ -e "$config_record" ]; then
    if should_mutate; then
      rollback_dir="$(mktemp -d)"
      rollback_file="$rollback_dir/config"
      agent_guidelines_backup_object "$config_path" "$rollback_file" || {
        rm -rf "$rollback_dir" "$temp_file"
        die "could not verify config rollback copy"
      }
      checksum="$(sha256_file "$temp_file")"
      if ! agent_guidelines_atomic_replace_file "$config_path" "$temp_file" ||
        ! replace_ownership_record config "sha256=$checksum"; then
        agent_guidelines_atomic_replace_file "$config_path" "$rollback_file" ||
          die "config update failed and rollback failed: $rollback_file"
        rm -rf "$rollback_dir" "$temp_file"
        die "config update failed; restored previous content"
      fi
      rm -rf "$rollback_dir"
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
      if ! agent_guidelines_atomic_replace_file "$config_path" "$temp_file"; then
        rm -f "$(ownership_record_path config)" "$temp_file"
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

  hook_path="$(git_path "hooks/$hook_name")"
  snippet_path="$ASSET_DIR/hooks/$snippet_name"

  validate_hook_snippet_target "$hook_name" "$snippet_name" || return 1

  if should_mutate; then
    mkdir -p "$(dirname "$hook_path")"
  fi
  if [ ! -e "$hook_path" ]; then
    if should_mutate; then
      printf '#!/bin/sh\n\n' > "$hook_path"
    fi
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
      printf '\n' >> "$hook_path"
      cat "$snippet_path" >> "$hook_path"
      printf '\n' >> "$hook_path"
    fi
    add_status updated "$hook_name $snippet_name"
  fi

  if should_mutate; then
    chmod +x "$hook_path"
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
    cp "$temp_file" "$hook_path"
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
    local current_template exclude_file exclude_type
    exclude_file="$(git_path info/exclude)"
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
    cp "$temp_file" "$hook_path"
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
    rm -f "$hook_path"
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
    agent_guidelines_atomic_replace_file "$exclude_file" "$temp_file" || {
      rm -f "$managed_list" "$temp_file"
      die "could not remove owned exclude lines"
    }
    for pair in "${MANAGED_EXCLUDE_RECORDS[@]}"; do
      key="${pair%%|*}"
      record_name="$(exclude_record_name "$key")"
      record_path="$(ownership_record_path "$record_name")"
      [ -e "$record_path" ] && rm -f "$record_path"
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
    git -C "$TARGET_DIR" config --local --unset commit.template
    rm -f "$record_path"
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
      rm -f "$target_file"
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
        rm -f "$rules_path"
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
      rm -f "$config_path" "$config_record"
    fi
    add_status updated ".agent-guidelines/config removed"
  elif [ -e "$config_path" ] || [ -L "$config_path" ]; then
    add_status skipped ".agent-guidelines/config has no ownership record"
  fi

  if should_mutate && [ -d "$state_dir" ]; then
    rmdir "$state_dir" 2>/dev/null || true
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
          rm -f "$entry"
        fi
        add_status updated ".agents/skills/$(basename "$entry") link removed"
      else
        add_status skipped ".agents/skills/$(basename "$entry") is unowned"
      fi
    else
      add_status skipped ".agents/skills/$(basename "$entry") is a copy"
    fi
  done

  if should_mutate; then
    rmdir "$skills_dir" "$TARGET_DIR/.agents" 2>/dev/null || true
  fi
}

cleanup_ownership_state() {
  target_has_git_repo || return 0
  if should_mutate; then
    rmdir "$(ownership_dir)" 2>/dev/null || true
    rmdir "$(dirname "$(ownership_dir)")" 2>/dev/null || true
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

  preflight_managed_targets || return 1

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
  cleanup_ownership_state

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
  local name
  local email
  branch="$(git -C "$TARGET_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached')"
  name="$(git config --get user.name || true)"
  email="$(git config --get user.email || true)"

  printf '\nProject setup summary\n'
  if [ "$DRY_RUN" = true ]; then
    printf 'Mode: dry-run (no files modified)\n'
  fi
  printf 'Repository: %s\n' "$TARGET_DIR"
  printf 'Branch: %s\n' "$branch"
  printf 'Git user: %s <%s>\n' "$name" "$email"
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

  if [ "$MODE" = "remove" ]; then
    run_remove
    return 0
  fi

  resolve_target
  require_git_identity
  infer_profile
  infer_changelog_mode
  preflight_managed_targets
  preflight_source_targets
  preflight_project_files
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
  write_local_config
  assemble_agent_files
  install_per_project_skills
  create_initial_commit_if_needed
  install_hooks
  print_summary
}

main "$@"
