#!/usr/bin/env bash
# Sets up a target repository with shared project rules and local git policy.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ASSET_DIR="${SCRIPT_DIR}/skills/project-setup/assets"
CANONICAL_RULES_DIR="${SCRIPT_DIR}/rules"

PROFILE="auto"
CHANGELOG_MODE="auto"
RULE_SOURCE_MODE="symlink"
TARGET_DIR="."
INCLUDE_RULES=()
EXCLUDE_RULES=()

CREATED=()
UPDATED=()
UNCHANGED=()
SKIPPED=()
WARNINGS=()

MARKER_BEGIN="<!-- BEGIN agent-guidelines project rules -->"
MARKER_END="<!-- END agent-guidelines project rules -->"

MINIMAL_RULES=(
  git-workflow
  git-messages
  development-attribution
  configuration
  testing
  documentation
)

CODEBASE_EXTRA_RULES=(
  docstrings
  dependencies
  scripts
)

RELEASED_EXTRA_RULES=(
  backward-compatibility
)

CANONICAL_RULE_ORDER=(
  git-workflow
  git-messages
  development-attribution
  configuration
  testing
  documentation
  docstrings
  scripts
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
  --rules-source symlink|copy
  --include-rule <id>
  --exclude-rule <id>
  -h, --help

Examples:
  ./project-setup.sh .
  ./project-setup.sh --profile codebase .
  ./project-setup.sh --profile released --changelog version .
  ./project-setup.sh --profile codebase --changelog date --include-rule docstrings .
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

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
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
      --rules-source)
        [ "$#" -ge 2 ] || die "--rules-source requires a value"
        RULE_SOURCE_MODE="$2"
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
  case "$RULE_SOURCE_MODE" in symlink|copy) ;; *) die "invalid rules source mode: $RULE_SOURCE_MODE" ;; esac
}

resolve_target() {
  mkdir -p "$TARGET_DIR"
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
  if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    add_status unchanged "git repository already exists"
    REPO_CREATED=false
  else
    git -C "$TARGET_DIR" init --initial-branch=main >/dev/null
    add_status created "git repository"
    REPO_CREATED=true
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
  elif find "$TARGET_DIR" -maxdepth 3 -type f \( \
    -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' -o \
    -name '*.go' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o \
    -name '*.tsx' -o -name '*.py' -o -name '*.rs' -o -name '*.java' -o \
    -name '*.sh' \) | sed -n '1q' | grep -q .; then
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

  if [ -e "$path" ]; then
    add_status unchanged "$label"
    return
  fi

  mkdir -p "$(dirname "$path")"
  cp "$source" "$path"
  add_status created "$label"
}

write_readme_if_missing() {
  local path="$TARGET_DIR/README.md"

  if [ -e "$path" ]; then
    add_status unchanged "README.md"
    return
  fi

  {
    printf '# %s\n\n' "$(basename "$TARGET_DIR")"
  } > "$path"
  add_status created "README.md"
}

configure_commit_template() {
  local current
  current="$(git -C "$TARGET_DIR" config --local --get commit.template || true)"

  if [ "$current" = ".gittemplate" ]; then
    add_status unchanged "git commit.template"
  else
    git -C "$TARGET_DIR" config --local commit.template .gittemplate
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

append_missing_line() {
  local file="$1"
  local line="$2"
  local label="$3"

  touch "$file"
  if grep -Fxq "$line" "$file"; then
    add_status unchanged "$label"
  else
    printf '%s\n' "$line" >> "$file"
    add_status updated "$label"
  fi
}

configure_local_excludes() {
  local exclude_file
  exclude_file="$(git_path info/exclude)"
  mkdir -p "$(dirname "$exclude_file")"

  append_missing_line "$exclude_file" "CLAUDE.md" "exclude CLAUDE.md"
  append_missing_line "$exclude_file" "CLAUDE.local.md" "exclude CLAUDE.local.md"
  append_missing_line "$exclude_file" "AGENTS.md" "exclude AGENTS.md"
  append_missing_line "$exclude_file" ".claude/" "exclude .claude/"
  append_missing_line "$exclude_file" ".codex/" "exclude .codex/"
  append_missing_line "$exclude_file" ".agent-guidelines/config" "exclude .agent-guidelines/config"
  if [ "$RULE_SOURCE_MODE" = "symlink" ]; then
    append_missing_line "$exclude_file" ".agent-guidelines/rules" "exclude .agent-guidelines/rules symlink"
  fi

  for local_file in opencode.json .mcp.json; do
    if git -C "$TARGET_DIR" ls-files --error-unmatch "$local_file" >/dev/null 2>&1; then
      add_status skipped "$local_file is tracked"
    else
      append_missing_line "$exclude_file" "$local_file" "exclude $local_file"
    fi
  done
}

configure_rule_source() {
  local state_dir="$TARGET_DIR/.agent-guidelines"
  local rules_path="$state_dir/rules"

  mkdir -p "$state_dir"

  if [ "$RULE_SOURCE_MODE" = "symlink" ]; then
    if [ -L "$rules_path" ]; then
      local current
      current="$(readlink "$rules_path")"
      if [ "$current" = "$CANONICAL_RULES_DIR" ]; then
        add_status unchanged ".agent-guidelines/rules symlink"
      else
        add_status skipped ".agent-guidelines/rules points to $current"
      fi
    elif [ -e "$rules_path" ]; then
      add_status skipped ".agent-guidelines/rules exists and is not a symlink"
      RULE_SOURCE_MODE="copy"
    else
      ln -s "$CANONICAL_RULES_DIR" "$rules_path"
      add_status created ".agent-guidelines/rules symlink"
    fi
  fi

  if [ "$RULE_SOURCE_MODE" = "copy" ]; then
    mkdir -p "$rules_path"
    cp "$CANONICAL_RULES_DIR"/*.md "$rules_path"/
    add_status updated ".agent-guidelines/rules snapshot"
  fi

  RULE_SOURCE_DIR="$rules_path"
  if [ ! -e "$RULE_SOURCE_DIR" ]; then
    RULE_SOURCE_DIR="$CANONICAL_RULES_DIR"
    add_status warning "using canonical rules directly because project rule source was unavailable"
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

assemble_rules_block() {
  local block_file="$1"
  local rules
  rules="$(selected_rules_ordered)"

  {
    printf '%s\n\n' "$MARKER_BEGIN"
    local rule
    while IFS= read -r rule; do
      [ -n "$rule" ] || continue
      local path="$RULE_SOURCE_DIR/$rule.md"
      if [ -f "$path" ]; then
        cat "$path"
        printf '\n\n'
      else
        add_status warning "selected rule unavailable: $rule"
      fi
    done <<< "$rules"
    printf '%s\n' "$MARKER_END"
  } > "$block_file"
}

update_managed_block() {
  local target_file="$1"
  local block_file="$2"
  local label="$3"
  local temp_file
  temp_file="$(mktemp)"

  if [ ! -e "$target_file" ]; then
    cp "$block_file" "$target_file"
    add_status created "$label"
    rm -f "$temp_file"
    return
  fi

  if grep -Fxq "$MARKER_BEGIN" "$target_file" && grep -Fxq "$MARKER_END" "$target_file"; then
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" -v block="$block_file" '
      $0 == begin {
        while ((getline line < block) > 0) print line
        in_block = 1
        next
      }
      $0 == end {
        in_block = 0
        next
      }
      !in_block { print }
    ' "$target_file" > "$temp_file"
  else
    cat "$target_file" > "$temp_file"
    printf '\n%s\n' "" >> "$temp_file"
    cat "$block_file" >> "$temp_file"
  fi

  if cmp -s "$target_file" "$temp_file"; then
    add_status unchanged "$label"
  else
    cp "$temp_file" "$target_file"
    add_status updated "$label"
  fi
  rm -f "$temp_file"
}

assemble_agent_files() {
  local block_file
  block_file="$(mktemp)"
  assemble_rules_block "$block_file"
  update_managed_block "$TARGET_DIR/CLAUDE.md" "$block_file" "CLAUDE.md project rules"
  update_managed_block "$TARGET_DIR/AGENTS.md" "$block_file" "AGENTS.md project rules"
  rm -f "$block_file"
}

write_local_config() {
  local config_path="$TARGET_DIR/.agent-guidelines/config"
  local temp_file
  local existed=false
  temp_file="$(mktemp)"

  {
    printf 'profile=%s\n' "$PROFILE"
    printf 'changelog=%s\n' "$CHANGELOG_MODE"
    printf 'versioning=%s\n' "$(versioning_mode)"
    printf 'rules_source=%s\n' "$RULE_SOURCE_MODE"
    printf 'include_rules=%s\n' "${INCLUDE_RULES[*]:-}"
    printf 'exclude_rules=%s\n' "${EXCLUDE_RULES[*]:-}"
  } > "$temp_file"

  if [ -e "$config_path" ] && cmp -s "$config_path" "$temp_file"; then
    add_status unchanged ".agent-guidelines/config"
  else
    [ -e "$config_path" ] && existed=true
    mkdir -p "$(dirname "$config_path")"
    cp "$temp_file" "$config_path"
    if [ "$existed" = true ]; then
      add_status updated ".agent-guidelines/config"
    else
      add_status created ".agent-guidelines/config"
    fi
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

  mkdir -p "$(dirname "$hook_path")"
  if [ ! -e "$hook_path" ]; then
    printf '#!/bin/sh\n\n' > "$hook_path"
    add_status created "$hook_name hook"
  fi

  local begin_marker
  begin_marker="$(sed -n '1p' "$snippet_path")"

  if grep -Fxq "$begin_marker" "$hook_path"; then
    replace_hook_block "$hook_path" "$snippet_path" "$begin_marker" "$hook_name $snippet_name"
  else
    printf '\n' >> "$hook_path"
    cat "$snippet_path" >> "$hook_path"
    printf '\n' >> "$hook_path"
    add_status updated "$hook_name $snippet_name"
  fi

  chmod +x "$hook_path"
}

replace_hook_block() {
  local hook_path="$1"
  local snippet_path="$2"
  local begin_marker="$3"
  local label="$4"
  local end_marker
  local temp_file

  end_marker="$(sed -n '$p' "$snippet_path")"
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
  install_hook_snippet pre-commit pre-commit-main-branch
  install_hook_snippet pre-commit pre-commit-attribution
  install_hook_snippet commit-msg commit-msg-attribution
  install_hook_snippet commit-msg commit-msg-conventional
  install_hook_snippet pre-push pre-push-branch-name
}

create_initial_commit_if_needed() {
  if [ "$REPO_CREATED" != true ]; then
    add_status skipped "initial commit because repository already existed"
    return
  fi

  local paths=(".gittemplate" ".gitignore" "README.md")
  if [ "$CHANGELOG_MODE" != "none" ]; then
    paths+=("CHANGELOG.md")
  fi
  if [ "$RULE_SOURCE_MODE" = "copy" ]; then
    paths+=(".agent-guidelines/rules")
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
  printf 'Repository: %s\n' "$TARGET_DIR"
  printf 'Branch: %s\n' "$branch"
  printf 'Git user: %s <%s>\n' "$name" "$email"
  printf 'Profile: %s\n' "$PROFILE"
  printf 'Changelog mode: %s\n' "$CHANGELOG_MODE"
  printf 'Versioning mode: %s\n' "$(versioning_mode)"
  printf 'Rule source mode: %s\n\n' "$RULE_SOURCE_MODE"

  print_list "Created:" "${CREATED[@]}"
  print_list "Updated:" "${UPDATED[@]}"
  print_list "Unchanged:" "${UNCHANGED[@]}"
  print_list "Skipped:" "${SKIPPED[@]}"
  print_list "Warnings:" "${WARNINGS[@]}"
}

main() {
  parse_args "$@"
  resolve_target
  require_git_identity
  init_git_if_needed
  infer_profile
  infer_changelog_mode

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
  create_initial_commit_if_needed
  install_hooks
  print_summary
}

main "$@"
