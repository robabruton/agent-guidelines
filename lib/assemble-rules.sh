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
#   agent_guidelines_read_frontmatter_field <file> <field>
#       Print the value of the named field from the file's leading YAML
#       frontmatter, or empty if the field or frontmatter is absent.
#   agent_guidelines_assemble_block <block_file> <rules_dir> <rule>...
#       Write a marker-bracketed block containing the named rule files
#       (with frontmatter stripped) to block_file. Each missing rule is
#       reported to stderr as "missing-rule: <name>".
#   agent_guidelines_update_managed_block <target_file> <block_file>
#       Replace an existing marker block in target_file with block_file's
#       contents, append the block if target_file lacks markers, or
#       create target_file from block_file. Prints "created", "updated",
#       or "unchanged" on stdout.
#   agent_guidelines_remove_managed_block <target_file>
#       Strip the marker block from target_file. Removes the file if it
#       becomes empty (or whitespace only). Prints "removed",
#       "cleared", "absent", or "missing" on stdout.
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

AGENT_GUIDELINES_MARKER_BEGIN="<!-- BEGIN agent-guidelines project rules -->"
AGENT_GUIDELINES_MARKER_END="<!-- END agent-guidelines project rules -->"

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
  temp_file="$(mktemp)"

  if [ ! -e "$target_file" ]; then
    mkdir -p "$(dirname "$target_file")"
    cp "$block_file" "$target_file"
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
    cp "$temp_file" "$target_file"
    result="updated"
  fi
  rm -f "$temp_file"
  printf '%s' "$result"
}

agent_guidelines_remove_managed_block() {
  local target_file="$1"
  local temp_file

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
    cp "$temp_file" "$target_file"
    rm -f "$temp_file"
    printf 'cleared'
  else
    rm -f "$temp_file" "$target_file"
    printf 'removed'
  fi
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
