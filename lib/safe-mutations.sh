#!/usr/bin/env bash
# Shared path, backup, verification, and atomic-write safety helpers.
#
# Callers remain responsible for deciding whether an object is owned. These
# helpers inspect paths without following the final component, prove path
# containment, create unique verified backups, and replace regular files only
# after the caller has established ownership or made a verified backup.

agent_guidelines_path_type() {
  local path="$1"

  if [ -L "$path" ]; then
    printf 'symlink'
  elif [ -f "$path" ]; then
    printf 'regular'
  elif [ -d "$path" ]; then
    printf 'directory'
  elif [ -e "$path" ]; then
    printf 'other'
  else
    printf 'missing'
  fi
}

agent_guidelines_physical_candidate() {
  local path="$1"
  local parent
  local suffix
  local part

  case "$path" in
    /*) ;;
    *) path="$PWD/$path" ;;
  esac

  parent="$(dirname "$path")"
  suffix="$(basename "$path")"
  while [ ! -d "$parent" ]; do
    if [ -L "$parent" ] || [ -e "$parent" ]; then
      printf 'error: path parent is not a directory: %s\n' "$parent" >&2
      return 1
    fi
    part="$(basename "$parent")"
    suffix="$part/$suffix"
    parent="$(dirname "$parent")"
  done

  printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$suffix"
}

agent_guidelines_assert_path_beneath() {
  local path="$1"
  local root="$2"
  local label="$3"
  local root_physical
  local candidate

  root_physical="$(cd "$root" && pwd -P)" || return 1
  candidate="$(agent_guidelines_physical_candidate "$path")" || return 1
  case "$candidate" in
    "$root_physical"|"$root_physical"/*) return 0 ;;
    *)
      printf 'error: %s escapes approved root %s: %s\n' \
        "$label" "$root_physical" "$candidate" >&2
      return 1
      ;;
  esac
}

agent_guidelines_stat_signature() {
  local path="$1"

  if stat -c '%a:%u:%g' "$path" >/dev/null 2>&1; then
    stat -c '%a:%u:%g' "$path"
  else
    stat -f '%Lp:%u:%g' "$path"
  fi
}

agent_guidelines_verify_copy() {
  local source="$1"
  local copy="$2"
  local source_type
  local copy_type
  local child
  local name

  source_type="$(agent_guidelines_path_type "$source")"
  copy_type="$(agent_guidelines_path_type "$copy")"
  if [ "$source_type" != "$copy_type" ]; then
    printf 'error: backup type mismatch for %s\n' "$source" >&2
    return 1
  fi

  case "$source_type" in
    regular)
      cmp -s "$source" "$copy" || {
        printf 'error: backup content mismatch for %s\n' "$source" >&2
        return 1
      }
      ;;
    symlink)
      if [ "$(readlink "$source")" != "$(readlink "$copy")" ]; then
        printf 'error: backup symlink mismatch for %s\n' "$source" >&2
        return 1
      fi
      return 0
      ;;
    directory)
      while IFS= read -r -d '' child; do
        name="$(basename "$child")"
        agent_guidelines_verify_copy "$child" "$copy/$name" || return 1
      done < <(find "$source" -mindepth 1 -maxdepth 1 -print0)
      while IFS= read -r -d '' child; do
        name="$(basename "$child")"
        if [ ! -e "$source/$name" ] && [ ! -L "$source/$name" ]; then
          printf 'error: backup contains an extra entry: %s\n' "$copy/$name" >&2
          return 1
        fi
      done < <(find "$copy" -mindepth 1 -maxdepth 1 -print0)
      ;;
    *)
      printf 'error: unsupported backup object type for %s: %s\n' \
        "$source" "$source_type" >&2
      return 1
      ;;
  esac

  if [ "$(agent_guidelines_stat_signature "$source")" != \
    "$(agent_guidelines_stat_signature "$copy")" ]; then
    printf 'error: backup metadata mismatch for %s\n' "$source" >&2
    return 1
  fi
}

agent_guidelines_create_backup_run() {
  local backup_parent="$1"

  if [ -L "$backup_parent" ]; then
    printf 'error: backup parent is a symlink: %s\n' "$backup_parent" >&2
    return 1
  fi
  if [ -e "$backup_parent" ] && [ ! -d "$backup_parent" ]; then
    printf 'error: backup parent is not a directory: %s\n' \
      "$backup_parent" >&2
    return 1
  fi

  mkdir -p "$backup_parent" || return 1
  mktemp -d "${backup_parent%/}/run.XXXXXX"
}

agent_guidelines_backup_object() {
  local source="$1"
  local destination="$2"
  local source_type

  source_type="$(agent_guidelines_path_type "$source")"
  case "$source_type" in
    regular|directory|symlink) ;;
    *)
      printf 'error: cannot back up %s object: %s\n' \
        "$source_type" "$source" >&2
      return 1
      ;;
  esac

  if [ -e "$destination" ] || [ -L "$destination" ]; then
    printf 'error: refusing to reuse backup destination: %s\n' \
      "$destination" >&2
    return 1
  fi

  mkdir -p "$(dirname "$destination")" || return 1
  cp -a "$source" "$destination" || return 1
  agent_guidelines_verify_copy "$source" "$destination"
}

agent_guidelines_restore_object() {
  local backup="$1"
  local destination="$2"

  if [ -e "$destination" ] || [ -L "$destination" ]; then
    printf 'error: refusing to restore over existing path: %s\n' \
      "$destination" >&2
    return 1
  fi
  cp -a "$backup" "$destination" || return 1
  agent_guidelines_verify_copy "$backup" "$destination"
}

agent_guidelines_atomic_replace_file() {
  local target="$1"
  local prepared="$2"
  local target_type
  local target_dir
  local temp_file

  target_type="$(agent_guidelines_path_type "$target")"
  case "$target_type" in
    missing|regular) ;;
    *)
      printf 'error: refusing regular-file replacement over %s: %s\n' \
        "$target_type" "$target" >&2
      return 1
      ;;
  esac

  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir" || return 1
  temp_file="$(mktemp "${target_dir}/.agent-guidelines.XXXXXX")" || return 1
  if ! cp "$prepared" "$temp_file"; then
    rm -f "$temp_file"
    return 1
  fi
  if [ "$target_type" = "regular" ]; then
    chmod "$(agent_guidelines_stat_signature "$target" | cut -d: -f1)" \
      "$temp_file" || {
      rm -f "$temp_file"
      return 1
    }
  else
    chmod "$(agent_guidelines_stat_signature "$prepared" | cut -d: -f1)" \
      "$temp_file" || {
      rm -f "$temp_file"
      return 1
    }
  fi
  if ! mv "$temp_file" "$target"; then
    rm -f "$temp_file"
    return 1
  fi
}
