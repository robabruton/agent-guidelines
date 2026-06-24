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
        agent_guidelines_strip_frontmatter "$path"
        printf '\n\n'
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
