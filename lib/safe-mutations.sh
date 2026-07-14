#!/usr/bin/env bash
# Shared path, backup, verification, and atomic-write safety helpers.
#
# Callers remain responsible for deciding whether an object is owned. These
# helpers inspect paths without following the final component, prove path
# containment, create unique verified backups, and replace regular files only
# after the caller has established ownership or made a verified backup.

AGENT_GUIDELINES_TRANSACTION_ACTIVE=false
AGENT_GUIDELINES_TRANSACTION_DIR=""
AGENT_GUIDELINES_TRANSACTION_RECOVERY_NOTE=""
AGENT_GUIDELINES_TRANSACTION_RETAIN_ENTRY=""

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

agent_guidelines_transaction_is_active() {
  [ "${AGENT_GUIDELINES_TRANSACTION_ACTIVE:-false}" = true ]
}

agent_guidelines_transaction_set_recovery_note() {
  AGENT_GUIDELINES_TRANSACTION_RECOVERY_NOTE="$1"
}

agent_guidelines_transaction_allocate_entry() {
  local path="$1"
  local intended_type="$2"
  local intended_value="${3:-}"
  local next
  local entry

  next="$(<"${AGENT_GUIDELINES_TRANSACTION_DIR}/next")"
  case "$next" in
    ''|*[!0-9]*)
      printf 'error: invalid transaction sequence state: %s\n' \
        "$AGENT_GUIDELINES_TRANSACTION_DIR" >&2
      return 1
      ;;
  esac
  entry="${AGENT_GUIDELINES_TRANSACTION_DIR}/entries/$(printf '%08d' "$next")"
  printf '%s\n' "$((next + 1))" > "${AGENT_GUIDELINES_TRANSACTION_DIR}/next"
  mkdir "$entry" || return 1
  printf '%s\0' "$path" > "$entry/path"

  local original_type
  original_type="$(agent_guidelines_path_type "$path")"
  printf '%s\n' "$original_type" > "$entry/original-type"
  case "$original_type" in
    missing) ;;
    regular|directory|symlink)
      agent_guidelines_backup_object "$path" "$entry/original" || {
        rm -rf "$entry"
        return 1
      }
      ;;
    *)
      printf 'error: transaction cannot protect %s object: %s\n' \
        "$original_type" "$path" >&2
      rm -rf "$entry"
      return 1
      ;;
  esac

  printf '%s\n' "$intended_type" > "$entry/intended-type"
  case "$intended_type" in
    missing|unknown) ;;
    regular|directory)
      agent_guidelines_backup_object "$intended_value" "$entry/intended" || {
        rm -rf "$entry"
        return 1
      }
      ;;
    symlink)
      ln -s "$intended_value" "$entry/intended" || {
        rm -rf "$entry"
        return 1
      }
      ;;
    *)
      printf 'error: invalid intended transaction type: %s\n' \
        "$intended_type" >&2
      rm -rf "$entry"
      return 1
      ;;
  esac

  : > "$entry/prepared"
  printf '%s\n' "$entry"
}

agent_guidelines_transaction_read_path() {
  local entry="$1"
  local path=""

  IFS= read -r -d '' path < "$entry/path" || true
  printf '%s' "$path"
}

agent_guidelines_transaction_discard_entries_beneath() {
  local root="$1"
  local entry path

  agent_guidelines_transaction_is_active || return 0
  for entry in "${AGENT_GUIDELINES_TRANSACTION_DIR}"/entries/*; do
    [ -d "$entry" ] || continue
    path="$(agent_guidelines_transaction_read_path "$entry")"
    case "$path" in
      "$root"|"$root"/*) rm -rf "$entry" ;;
    esac
  done
}

agent_guidelines_transaction_retain_entry() {
  local entry="$1"

  agent_guidelines_transaction_is_active || return 1
  [ -d "$entry" ] || return 1
  AGENT_GUIDELINES_TRANSACTION_RETAIN_ENTRY="$entry"
}

agent_guidelines_transaction_matches() {
  local path="$1"
  local type="$2"
  local snapshot="${3:-}"
  local strict="${4:-strict}"

  case "$type" in
    unknown) return 1 ;;
    missing)
      [ ! -e "$path" ] && [ ! -L "$path" ]
      ;;
    regular)
      [ -f "$path" ] && [ ! -L "$path" ] || return 1
      if [ "$strict" = strict ]; then
        agent_guidelines_verify_copy "$snapshot" "$path" >/dev/null 2>&1
      else
        cmp -s "$snapshot" "$path"
      fi
      ;;
    directory)
      [ -d "$path" ] && [ ! -L "$path" ] || return 1
      agent_guidelines_verify_copy "$snapshot" "$path" >/dev/null 2>&1
      ;;
    symlink)
      [ -L "$path" ] || return 1
      if [ "$strict" = strict ]; then
        agent_guidelines_verify_copy "$snapshot" "$path" >/dev/null 2>&1
      else
        [ "$(readlink "$snapshot")" = "$(readlink "$path")" ]
      fi
      ;;
    *) return 1 ;;
  esac
}

agent_guidelines_transaction_remove_current() {
  local path="$1"
  local type

  type="$(agent_guidelines_path_type "$path")"
  case "$type" in
    missing) return 0 ;;
    regular|symlink) rm -f "$path" ;;
    directory) rm -rf "$path" ;;
    *)
      printf 'error: transaction cannot remove %s object: %s\n' \
        "$type" "$path" >&2
      return 1
      ;;
  esac
}

agent_guidelines_transaction_restore_original() {
  local entry="$1"
  local path="$2"
  local original_type

  original_type="$(<"$entry/original-type")"
  agent_guidelines_transaction_remove_current "$path" || return 1
  if [ "$original_type" != missing ]; then
    agent_guidelines_restore_object "$entry/original" "$path" || return 1
  fi
  agent_guidelines_transaction_matches \
    "$path" "$original_type" "$entry/original" strict
}

agent_guidelines_transaction_complete_entry() {
  local entry="$1"
  local path
  local expected_type

  path="$(agent_guidelines_transaction_read_path "$entry")"
  expected_type="$(agent_guidelines_path_type "$path")"
  printf '%s\n' "$expected_type" > "$entry/expected-type"
  if [ "$expected_type" != missing ]; then
    agent_guidelines_backup_object "$path" "$entry/expected" || return 1
  fi
  : > "$entry/complete"
}

agent_guidelines_transaction_cancel_entry() {
  local entry="$1"
  local path
  local original_type
  local intended_type

  path="$(agent_guidelines_transaction_read_path "$entry")"
  original_type="$(<"$entry/original-type")"
  intended_type="$(<"$entry/intended-type")"

  if agent_guidelines_transaction_matches \
    "$path" "$original_type" "$entry/original" strict; then
    rm -rf "$entry"
    return 0
  fi
  if ! agent_guidelines_transaction_matches \
    "$path" "$intended_type" "$entry/intended" lenient; then
    printf 'error: transaction target changed unexpectedly; recovery copy: %s\n' \
      "$entry" >&2
    return 1
  fi
  agent_guidelines_transaction_restore_original "$entry" "$path" || {
    printf 'error: transaction restore failed; recovery copy: %s\n' \
      "$entry" >&2
    return 1
  }
  rm -rf "$entry"
}

agent_guidelines_transaction_rollback_entry() {
  local entry="$1"
  local path
  local original_type
  local expected_type

  if [ "$entry" = \
    "${AGENT_GUIDELINES_TRANSACTION_RETAIN_ENTRY:-}" ]; then
    printf 'error: uncertain transaction entry retained: %s\n' \
      "$entry" >&2
    return 1
  fi

  if [ ! -e "$entry/complete" ]; then
    agent_guidelines_transaction_cancel_entry "$entry"
    return
  fi

  path="$(agent_guidelines_transaction_read_path "$entry")"
  original_type="$(<"$entry/original-type")"
  expected_type="$(<"$entry/expected-type")"
  if ! agent_guidelines_transaction_matches \
    "$path" "$expected_type" "$entry/expected" strict; then
    printf 'error: completed transaction target changed; recovery copy: %s\n' \
      "$entry" >&2
    return 1
  fi
  agent_guidelines_transaction_restore_original "$entry" "$path" || {
    printf 'error: transaction rollback failed; recovery copy: %s\n' \
      "$entry" >&2
    return 1
  }
  if ! agent_guidelines_transaction_matches \
    "$path" "$original_type" "$entry/original" strict; then
    printf 'error: transaction rollback verification failed: %s\n' \
      "$path" >&2
    return 1
  fi
  rm -rf "$entry"
}

agent_guidelines_transaction_rollback() {
  local entries=()
  local entry
  local index
  local failed=false

  [ -n "${AGENT_GUIDELINES_TRANSACTION_DIR:-}" ] || return 0
  for entry in "${AGENT_GUIDELINES_TRANSACTION_DIR}"/entries/*; do
    [ -d "$entry" ] && entries+=("$entry")
  done
  for ((index = ${#entries[@]} - 1; index >= 0; index--)); do
    agent_guidelines_transaction_rollback_entry "${entries[$index]}" || failed=true
  done

  AGENT_GUIDELINES_TRANSACTION_ACTIVE=false
  if [ "$failed" = true ]; then
    printf 'error: transaction rollback incomplete; recovery directory: %s\n' \
      "$AGENT_GUIDELINES_TRANSACTION_DIR" >&2
    return 1
  fi
  rm -rf "$AGENT_GUIDELINES_TRANSACTION_DIR"
  AGENT_GUIDELINES_TRANSACTION_DIR=""
}

agent_guidelines_transaction_on_exit() {
  local status="$1"
  local rollback_status=0

  trap - EXIT
  set +e
  if agent_guidelines_transaction_is_active; then
    if [ "$status" -eq 0 ]; then
      printf 'error: transaction exited without commit\n' >&2
      status=1
    fi
    agent_guidelines_transaction_rollback
    rollback_status=$?
    [ "$rollback_status" -eq 0 ] || status=1
  fi
  if [ -n "${AGENT_GUIDELINES_TRANSACTION_RECOVERY_NOTE:-}" ]; then
    printf 'error: recovery state retained: %s\n' \
      "$AGENT_GUIDELINES_TRANSACTION_RECOVERY_NOTE" >&2
  fi
  exit "$status"
}

agent_guidelines_transaction_begin() {
  if agent_guidelines_transaction_is_active; then
    printf 'error: a mutation transaction is already active\n' >&2
    return 1
  fi

  AGENT_GUIDELINES_TRANSACTION_DIR="$(mktemp -d)" || return 1
  AGENT_GUIDELINES_TRANSACTION_RECOVERY_NOTE=""
  AGENT_GUIDELINES_TRANSACTION_RETAIN_ENTRY=""
  mkdir "${AGENT_GUIDELINES_TRANSACTION_DIR}/entries" || return 1
  printf '1\n' > "${AGENT_GUIDELINES_TRANSACTION_DIR}/next"
  AGENT_GUIDELINES_TRANSACTION_ACTIVE=true
  trap 'agent_guidelines_transaction_on_exit "$?"' EXIT
}

agent_guidelines_transaction_commit() {
  agent_guidelines_transaction_is_active || return 0
  rm -rf "$AGENT_GUIDELINES_TRANSACTION_DIR" || return 1
  AGENT_GUIDELINES_TRANSACTION_DIR=""
  AGENT_GUIDELINES_TRANSACTION_ACTIVE=false
  AGENT_GUIDELINES_TRANSACTION_RECOVERY_NOTE=""
  AGENT_GUIDELINES_TRANSACTION_RETAIN_ENTRY=""
  trap - EXIT
}

agent_guidelines_make_directory_safely() {
  local path="$1"
  local parent
  local empty
  local transaction_entry=""

  if [ -d "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi
  if [ -e "$path" ] || [ -L "$path" ]; then
    printf 'error: directory target conflicts: %s\n' "$path" >&2
    return 1
  fi
  parent="$(dirname "$path")"
  if [ "$parent" != "$path" ]; then
    agent_guidelines_make_directory_safely "$parent" || return 1
  fi

  if agent_guidelines_transaction_is_active; then
    empty="$(mktemp -d)" || return 1
    transaction_entry="$(agent_guidelines_transaction_allocate_entry \
      "$path" directory "$empty")" || {
      rmdir "$empty"
      return 1
    }
    rmdir "$empty"
  fi
  if ! mkdir "$path"; then
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
  agent_guidelines_make_directory_safely "$target_dir" || return 1
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

agent_guidelines_replace_file_safely() {
  local target="$1"
  local prepared="$2"
  local target_type
  local rollback_dir=""
  local rollback_file=""
  local transaction_entry=""

  target_type="$(agent_guidelines_path_type "$target")"
  case "$target_type" in
    regular)
      rollback_dir="$(mktemp -d)" || return 1
      rollback_file="$rollback_dir/target"
      agent_guidelines_backup_object "$target" "$rollback_file" || {
        printf 'error: verified rollback copy failed for %s\n' "$target" >&2
        return 1
      }
      ;;
    missing) ;;
    *)
      printf 'error: refusing safe replacement over %s: %s\n' \
        "$target_type" "$target" >&2
      return 1
      ;;
  esac

  if agent_guidelines_transaction_is_active; then
    agent_guidelines_make_directory_safely "$(dirname "$target")" || return 1
    transaction_entry="$(agent_guidelines_transaction_allocate_entry \
      "$target" regular "$prepared")" || return 1
    if agent_guidelines_atomic_replace_file "$target" "$prepared" &&
      cmp -s "$target" "$prepared"; then
      if agent_guidelines_transaction_complete_entry "$transaction_entry"; then
        return 0
      fi
    fi
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || return 1
    printf 'error: safe transactional replacement failed for %s\n' \
      "$target" >&2
    return 1
  fi

  if agent_guidelines_atomic_replace_file "$target" "$prepared" &&
    cmp -s "$target" "$prepared"; then
    [ -n "$rollback_dir" ] && rm -rf "$rollback_dir"
    return 0
  fi

  if [ "$target_type" = regular ]; then
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      agent_guidelines_atomic_replace_file "$target" "$rollback_file" || {
        printf 'error: replacement rollback failed; recovery copy: %s\n' \
          "$rollback_file" >&2
        return 1
      }
    elif [ ! -e "$target" ] && [ ! -L "$target" ]; then
      agent_guidelines_restore_object "$rollback_file" "$target" || {
        printf 'error: replacement restore failed; recovery copy: %s\n' \
          "$rollback_file" >&2
        return 1
      }
    else
      printf 'error: replacement changed target type; recovery copy: %s\n' \
        "$rollback_file" >&2
      return 1
    fi
    rm -rf "$rollback_dir"
  elif [ -f "$target" ] && [ ! -L "$target" ]; then
    rm -f "$target"
  fi

  printf 'error: safe replacement failed for %s; original restored\n' \
    "$target" >&2
  return 1
}

agent_guidelines_remove_file_safely() {
  local target="$1"
  local target_type
  local rollback_dir
  local rollback_file
  local transaction_entry=""

  target_type="$(agent_guidelines_path_type "$target")"
  if [ "$target_type" = missing ]; then
    return 0
  fi
  if [ "$target_type" != regular ]; then
    printf 'error: refusing safe file removal of %s: %s\n' \
      "$target_type" "$target" >&2
    return 1
  fi

  if agent_guidelines_transaction_is_active; then
    transaction_entry="$(agent_guidelines_transaction_allocate_entry \
      "$target" missing)" || return 1
    if rm -f "$target" && [ ! -e "$target" ] && [ ! -L "$target" ]; then
      if agent_guidelines_transaction_complete_entry "$transaction_entry"; then
        return 0
      fi
    fi
    agent_guidelines_transaction_cancel_entry "$transaction_entry" || return 1
    printf 'error: safe transactional removal failed for %s\n' "$target" >&2
    return 1
  fi

  rollback_dir="$(mktemp -d)" || return 1
  rollback_file="$rollback_dir/target"
  agent_guidelines_backup_object "$target" "$rollback_file" || {
    printf 'error: verified removal backup failed for %s\n' "$target" >&2
    return 1
  }

  if rm -f "$target" && [ ! -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$rollback_dir"
    return 0
  fi

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    agent_guidelines_restore_object "$rollback_file" "$target" || {
      printf 'error: removal restore failed; recovery copy: %s\n' \
        "$rollback_file" >&2
      return 1
    }
  fi
  rm -rf "$rollback_dir"
  printf 'error: safe removal failed for %s; original retained\n' \
    "$target" >&2
  return 1
}
