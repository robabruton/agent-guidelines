#!/usr/bin/env bash
# Shared library for assembling marker-bracketed rule blocks.
#
# Source this file from a script that needs to write a managed rule block
# into a target file (CLAUDE.md, AGENTS.md, or similar). The library
# exposes:
#
#   AGENT_GUIDELINES_MARKER_BEGIN / AGENT_GUIDELINES_MARKER_END
#       The literal marker lines that delimit a managed block.
#   agent_guidelines_strip_frontmatter <file>
#       Print the file's content with any leading YAML frontmatter
#       removed.
#   agent_guidelines_format_rule_body <file>
#       Print the file's body (frontmatter stripped) with every ATX
#       heading at level 1-5 demoted by one level, so a rule's H1
#       title becomes an H2 section in the assembled document. H6
#       headings are left at H6 (the markdown maximum). Hash
#       characters inside fenced code blocks are not touched.
#   agent_guidelines_format_hard_constraints <file>
#       Print the rule title and its Hard Constraints section as nested
#       headings suitable for a compact project policy entrypoint.
#   agent_guidelines_read_frontmatter_field <file> <field>
#       Print the value of the named field from the file's leading YAML
#       frontmatter, or empty if the field or frontmatter is absent.
#   agent_guidelines_assemble_block <block_file> <rules_dir> <rule>...
#       Write a marker-bracketed block containing the named rule files
#       (with frontmatter stripped) to block_file. Each missing rule is
#       reported to stderr as "missing-rule: <name>".
#   agent_guidelines_validate_marker_pair <target_file> <begin> <end> <label>
#       Reject symlinks, non-regular files, and malformed marker pairs.
#       A regular file may contain either no markers or exactly one ordered
#       pair. Missing files are valid because callers may create them.
#   agent_guidelines_validate_managed_block_file <target_file>
#       Validate the standard project-rules marker pair in target_file.
#   agent_guidelines_update_managed_block <target_file> <block_file>
#       Replace an existing marker block in target_file with block_file's
#       contents, append the block if target_file lacks markers, or
#       create target_file from block_file. Prints "created", "updated",
#       or "unchanged" on stdout.
#   agent_guidelines_remove_managed_block <target_file>
#       Strip the marker block from target_file. Removes the file if it
#       becomes empty (or whitespace only). Prints "removed",
#       "cleared", "absent", or "missing" on stdout.
#   agent_guidelines_extract_managed_block <target_file>
#       Print the marker block from target_file, including both marker
#       lines, so callers can compare the installed block against a
#       freshly assembled one. Prints nothing when no block exists.
#   agent_guidelines_build_router_table <rules_dir> <stable_path> <rule>...
#       Print a markdown table to stdout listing each rule's "when"
#       trigger and a stable reference path (stable_path/<rule>.md) so a
#       model can read the rule on demand.
#   agent_guidelines_build_skill_router_table <skills_dir> <skill>...
#       Print a markdown table to stdout listing each skill's
#       "when_to_use" trigger. Skills are invoked by name, so no path
#       column is emitted. Reads SKILL.md frontmatter from
#       skills_dir/<skill>/SKILL.md. A leading "Use when " prefix on
#       the value is stripped so the cell completes the column header
#       without doubling.

ASSEMBLE_RULES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/safe-mutations.sh
. "${ASSEMBLE_RULES_LIB_DIR}/safe-mutations.sh"
unset ASSEMBLE_RULES_LIB_DIR

AGENT_GUIDELINES_MARKER_BEGIN="<!-- BEGIN agent-guidelines project rules -->"
AGENT_GUIDELINES_MARKER_END="<!-- END agent-guidelines project rules -->"

agent_guidelines_validate_marker_pair() {
  local target_file="$1"
  local begin_marker="$2"
  local end_marker="$3"
  local label="$4"
  local begin_count
  local end_count
  local begin_line
  local end_line

  if [ -L "$target_file" ]; then
    printf 'error: refusing to manage symlinked %s: %s\n' \
      "$label" "$target_file" >&2
    return 1
  fi

  [ -e "$target_file" ] || return 0

  if [ ! -f "$target_file" ]; then
    printf 'error: refusing to manage non-regular %s: %s\n' \
      "$label" "$target_file" >&2
    return 1
  fi

  begin_count="$(grep -Fxc "$begin_marker" "$target_file" || true)"
  end_count="$(grep -Fxc "$end_marker" "$target_file" || true)"

  if [ "$begin_count" -eq 0 ] && [ "$end_count" -eq 0 ]; then
    return 0
  fi

  if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
    printf 'error: malformed %s markers in %s (begin=%s, end=%s)\n' \
      "$label" "$target_file" "$begin_count" "$end_count" >&2
    return 1
  fi

  begin_line="$(grep -Fn "$begin_marker" "$target_file" | cut -d: -f1)"
  end_line="$(grep -Fn "$end_marker" "$target_file" | cut -d: -f1)"
  if [ "$begin_line" -ge "$end_line" ]; then
    printf 'error: reversed %s markers in %s\n' \
      "$label" "$target_file" >&2
    return 1
  fi
}

agent_guidelines_validate_managed_block_file() {
  local target_file="$1"

  agent_guidelines_validate_marker_pair \
    "$target_file" \
    "$AGENT_GUIDELINES_MARKER_BEGIN" \
    "$AGENT_GUIDELINES_MARKER_END" \
    "project-rules block"
}

agent_guidelines_strip_frontmatter() {
  local file="$1"

  awk '
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
    in_fm && /^---[[:space:]]*$/ { in_fm = 0; next }
    in_fm { next }
    { print }
  ' "$file"
}

agent_guidelines_format_rule_body() {
  local file="$1"

  agent_guidelines_strip_frontmatter "$file" |
    awk '
      BEGIN { in_code = 0 }
      /^```/ { in_code = !in_code; print; next }
      !in_code && /^#{1,5} / { print "#" $0; next }
      { print }
    '
}

agent_guidelines_format_hard_constraints() {
  local file="$1"

  agent_guidelines_strip_frontmatter "$file" |
    awk '
      BEGIN { in_constraints = 0; saw_constraint = 0 }
      /^# / {
        title = $0
        sub(/^# /, "", title)
        print "### " title
        next
      }
      /^## Hard Constraints[[:space:]]*$/ {
        print ""
        print "#### Hard Constraints"
        in_constraints = 1
        next
      }
      in_constraints && /^## / { exit }
      in_constraints && /^-/ { saw_constraint = 1 }
      in_constraints && saw_constraint && /^[[:space:]]*$/ { exit }
      in_constraints { print }
    '
}

agent_guidelines_read_frontmatter_field() {
  local file="$1"
  local field="$2"

  awk -v field="$field" '
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm {
      key = $0
      sub(/:.*$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key == field) {
        value = $0
        sub(/^[^:]*:[[:space:]]*/, "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

agent_guidelines_assemble_block() {
  local block_file="$1"
  local rules_dir="$2"
  shift 2

  {
    printf '%s\n\n' "$AGENT_GUIDELINES_MARKER_BEGIN"
    local rule
    for rule in "$@"; do
      [ -n "$rule" ] || continue
      local path="$rules_dir/$rule.md"
      if [ -f "$path" ]; then
        agent_guidelines_format_rule_body "$path"
        printf '\n'
      else
        printf 'missing-rule: %s\n' "$rule" >&2
      fi
    done
    printf '%s\n' "$AGENT_GUIDELINES_MARKER_END"
  } > "$block_file"
}

agent_guidelines_update_managed_block() {
  local target_file="$1"
  local block_file="$2"
  local temp_file

  agent_guidelines_validate_managed_block_file "$target_file" || return 1
  temp_file="$(mktemp)"

  if [ ! -e "$target_file" ]; then
    if ! agent_guidelines_replace_file_safely "$target_file" "$block_file"; then
      rm -f "$temp_file"
      return 1
    fi
    rm -f "$temp_file"
    printf 'created'
    return
  fi

  if grep -Fxq "$AGENT_GUIDELINES_MARKER_BEGIN" "$target_file" &&
    grep -Fxq "$AGENT_GUIDELINES_MARKER_END" "$target_file"; then
    awk \
      -v begin="$AGENT_GUIDELINES_MARKER_BEGIN" \
      -v end="$AGENT_GUIDELINES_MARKER_END" \
      -v block="$block_file" '
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

  local result
  if cmp -s "$target_file" "$temp_file"; then
    result="unchanged"
  else
    agent_guidelines_validate_managed_block_file "$target_file" || {
      rm -f "$temp_file"
      return 1
    }
    if ! agent_guidelines_replace_file_safely "$target_file" "$temp_file"; then
      rm -f "$temp_file"
      return 1
    fi
    result="updated"
  fi
  rm -f "$temp_file"
  printf '%s' "$result"
}

agent_guidelines_remove_managed_block() {
  local target_file="$1"
  local temp_file

  agent_guidelines_validate_managed_block_file "$target_file" || return 1

  if [ ! -e "$target_file" ]; then
    printf 'missing'
    return
  fi

  if ! grep -Fxq "$AGENT_GUIDELINES_MARKER_BEGIN" "$target_file" ||
    ! grep -Fxq "$AGENT_GUIDELINES_MARKER_END" "$target_file"; then
    printf 'absent'
    return
  fi

  temp_file="$(mktemp)"
  awk \
    -v begin="$AGENT_GUIDELINES_MARKER_BEGIN" \
    -v end="$AGENT_GUIDELINES_MARKER_END" '
    $0 == begin { in_block = 1; next }
    $0 == end   { in_block = 0; next }
    !in_block   { print }
  ' "$target_file" > "$temp_file"

  if grep -Eq '[^[:space:]]' "$temp_file"; then
    agent_guidelines_validate_managed_block_file "$target_file" || {
      rm -f "$temp_file"
      return 1
    }
    if ! agent_guidelines_replace_file_safely "$target_file" "$temp_file"; then
      rm -f "$temp_file"
      return 1
    fi
    rm -f "$temp_file"
    printf 'cleared'
  else
    rm -f "$temp_file"
    agent_guidelines_validate_managed_block_file "$target_file" || return 1
    agent_guidelines_remove_file_safely "$target_file" || return 1
    printf 'removed'
  fi
}

agent_guidelines_extract_managed_block() {
  local target_file="$1"

  agent_guidelines_validate_managed_block_file "$target_file" || return 1

  [ -e "$target_file" ] || return 0

  awk \
    -v begin="$AGENT_GUIDELINES_MARKER_BEGIN" \
    -v end="$AGENT_GUIDELINES_MARKER_END" '
    $0 == begin { in_block = 1 }
    in_block    { print }
    $0 == end && in_block { exit }
  ' "$target_file"
}

agent_guidelines_build_router_table() {
  local rules_dir="$1"
  local stable_path="$2"
  shift 2

  printf '| Rule | Read when | Path |\n'
  printf '| --- | --- | --- |\n'
  local rule
  for rule in "$@"; do
    [ -n "$rule" ] || continue
    local file="$rules_dir/$rule.md"
    [ -f "$file" ] || continue
    local when
    when="$(agent_guidelines_read_frontmatter_field "$file" when)"
    # shellcheck disable=SC2016
    # The single-quoted format string is intentional: printf substitutes
    # the %s placeholders from the positional arguments; we do not want
    # shell expansion of the format string itself.
    printf '| %s | %s | `%s/%s.md` |\n' \
      "$rule" "$when" "$stable_path" "$rule"
  done
}

agent_guidelines_build_skill_router_table() {
  local skills_dir="$1"
  shift

  printf '| Skill | Use when |\n'
  printf '| --- | --- |\n'
  local skill
  for skill in "$@"; do
    [ -n "$skill" ] || continue
    local file="$skills_dir/$skill/SKILL.md"
    [ -f "$file" ] || continue
    local when_to_use
    when_to_use="$(agent_guidelines_read_frontmatter_field "$file" when_to_use)"
    when_to_use="${when_to_use#Use when }"
    printf '| %s | %s |\n' "$skill" "$when_to_use"
  done
}
