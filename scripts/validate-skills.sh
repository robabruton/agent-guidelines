#!/usr/bin/env bash
# Validates the repository's Agent Skills metadata, catalog, and references.

set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
SKILLS_DIR="${REPO_DIR}/skills"
CATALOG_FILE="${SKILLS_DIR}/README.md"
SETUP_FILE="${REPO_DIR}/setup.sh"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-skill-validation.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

fail=0

report_error() {
  printf 'error: %s\n' "$*" >&2
  fail=1
}

frontmatter_value() {
  local file="$1"
  local field="$2"

  awk -v field="$field" '
    index($0, field ":") == 1 {
      value = substr($0, length(field) + 2)
      sub(/^[[:space:]]+/, "", value)
      header = value
      sub(/[[:space:]]+#.*$/, "", header)
      if (header ~ /^[>|]([+-]?[0-9]?|[0-9]?[+-]?)$/) {
        in_block = 1
        next
      }
      print value
      exit
    }
    in_block && $0 == "" {
      print
      next
    }
    in_block && /^[[:space:]]/ {
      value = $0
      sub(/^[[:space:]]+/, "", value)
      print value
      next
    }
    in_block { exit }
  ' "$file"
}

physical_path() {
  local path="$1"
  local target

  while [ -L "$path" ]; do
    target="$(readlink "$path")" || return 1
    case "$target" in
      /*) path="$target" ;;
      *) path="$(dirname "$path")/$target" ;;
    esac
  done
  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
  else
    printf '%s/%s\n' \
      "$(cd "$(dirname "$path")" && pwd -P)" "$(basename "$path")"
  fi
}

extract_markdown_links() {
  awk '
    {
      line = $0
      while (match(line, /\]\([^)]*\)/)) {
        print substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

validate_reference() {
  local skill_dir="$1"
  local skill_file="$2"
  local reference="$3"
  local candidate resolved skill_root

  reference="${reference%%#*}"
  case "$reference" in
    ""|\#*|http://*|https://*|mailto:*) return ;;
    /*|../*|*/../*)
      report_error "$skill_file has an out-of-scope reference: $reference"
      return
      ;;
  esac

  candidate="$skill_dir/$reference"
  if [ ! -e "$candidate" ]; then
    report_error "$skill_file references a missing path: $reference"
    return
  fi
  resolved="$(physical_path "$candidate")" || {
    report_error "$skill_file could not resolve reference: $reference"
    return
  }
  skill_root="$(cd "$skill_dir" && pwd -P)"
  case "$resolved" in
    "$skill_root"|"$skill_root"/*) ;;
    *) report_error "$skill_file has an out-of-scope reference: $reference" ;;
  esac
}

validate_skill() {
  local skill_dir="$1"
  local directory_name="${skill_dir##*/}"
  local skill_file="$skill_dir/SKILL.md"
  local frontmatter_file="$TMP_ROOT/${directory_name}.frontmatter"
  local end_line line field value metadata_active=false
  local scalar_block_active=false
  local name description when_to_use argument_hint compatibility allowed_tools
  local reference
  local name_count description_count when_count argument_count
  local compatibility_count allowed_count metadata_count body_lines

  if [ ! -f "$skill_file" ]; then
    report_error "$skill_dir is missing SKILL.md"
    return
  fi
  if [ "$(sed -n '1p' "$skill_file")" != "---" ]; then
    report_error "$skill_file is missing its opening frontmatter delimiter"
    return
  fi

  end_line="$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$skill_file")"
  if [ -z "$end_line" ]; then
    report_error "$skill_file is missing its closing frontmatter delimiter"
    return
  fi
  sed -n "2,$((end_line - 1))p" "$skill_file" > "$frontmatter_file"

  while IFS= read -r line; do
    case "$line" in
      ""|\#*) continue ;;
      [[:space:]]*)
        if [ "$metadata_active" != true ] &&
          [ "$scalar_block_active" != true ]; then
          report_error "$skill_file has unsupported nested frontmatter"
        fi
        continue
        ;;
    esac

    field="${line%%:*}"
    metadata_active=false
    scalar_block_active=false
    case "$field" in
      name|description|license|compatibility|allowed-tools|when_to_use|argument-hint)
        value="${line#*:}"
        value="${value%%#*}"
        value="${value//[[:space:]]/}"
        if printf '%s\n' "$value" |
          grep -Eq '^[>|]([+-]?[0-9]?|[0-9]?[+-]?)$'; then
          scalar_block_active=true
        fi
        ;;
      metadata)
        metadata_active=true
        ;;
      *)
        report_error "$skill_file has unsupported frontmatter field: $field"
        ;;
    esac
  done < "$frontmatter_file"

  name_count="$(grep -c '^name:' "$frontmatter_file" || true)"
  description_count="$(grep -c '^description:' "$frontmatter_file" || true)"
  when_count="$(grep -c '^when_to_use:' "$frontmatter_file" || true)"
  argument_count="$(grep -c '^argument-hint:' "$frontmatter_file" || true)"
  if [ "$name_count" -ne 1 ]; then
    report_error "$skill_file must contain exactly one name field"
  fi
  if [ "$description_count" -ne 1 ]; then
    report_error "$skill_file must contain exactly one description field"
  fi
  if [ "$when_count" -ne 1 ]; then
    report_error "$skill_file must contain exactly one when_to_use field"
  fi
  if [ "$argument_count" -ne 1 ]; then
    report_error "$skill_file must contain exactly one argument-hint field"
  fi

  name="$(frontmatter_value "$frontmatter_file" name | sed -n '1p')"
  description="$(frontmatter_value "$frontmatter_file" description | sed -n '1p')"
  when_to_use="$(frontmatter_value "$frontmatter_file" when_to_use | sed -n '1p')"
  argument_hint="$(frontmatter_value "$frontmatter_file" argument-hint | sed -n '1p')"
  if [ -n "$name" ]; then
    case "$name" in
      -*|*-|*--*|*[!a-z0-9-]*)
        report_error "$skill_file has an invalid skill name: $name"
        ;;
    esac
    if [ "${#name}" -gt 64 ]; then
      report_error "$skill_file name exceeds 64 characters"
    fi
    if [ "$name" != "$directory_name" ]; then
      report_error "$skill_file name does not match directory: $name"
    fi
  fi
  if [ -z "$description" ]; then
    report_error "$skill_file has an empty description"
  elif [ "${#description}" -gt 1024 ]; then
    report_error "$skill_file description exceeds 1024 characters"
  fi
  if [ -z "$when_to_use" ]; then
    report_error "$skill_file has an empty when_to_use field"
  fi
  if [ -z "$argument_hint" ]; then
    report_error "$skill_file has an empty argument-hint field"
  fi

  compatibility_count="$(grep -c '^compatibility:' "$frontmatter_file" || true)"
  if [ "$compatibility_count" -gt 1 ]; then
    report_error "$skill_file contains duplicate compatibility fields"
  elif [ "$compatibility_count" -eq 1 ]; then
    compatibility="$(frontmatter_value "$frontmatter_file" compatibility)"
    if [ -z "$compatibility" ] || [ "${#compatibility}" -gt 500 ]; then
      report_error "$skill_file compatibility must contain 1-500 characters"
    fi
  fi
  allowed_count="$(grep -c '^allowed-tools:' "$frontmatter_file" || true)"
  if [ "$allowed_count" -gt 1 ]; then
    report_error "$skill_file contains duplicate allowed-tools fields"
  elif [ "$allowed_count" -eq 1 ]; then
    allowed_tools="$(frontmatter_value "$frontmatter_file" allowed-tools)"
    if [ -z "$allowed_tools" ]; then
      report_error "$skill_file has an empty allowed-tools field"
    fi
  fi
  metadata_count="$(grep -c '^metadata:' "$frontmatter_file" || true)"
  if [ "$metadata_count" -gt 1 ]; then
    report_error "$skill_file contains duplicate metadata fields"
  fi

  body_lines="$(awk -v end="$end_line" 'NR > end && NF { count++ } END { print count + 0 }' "$skill_file")"
  if [ "$body_lines" -eq 0 ]; then
    report_error "$skill_file has an empty instruction body"
  fi
  if [ "$(wc -l < "$skill_file")" -gt 500 ]; then
    report_error "$skill_file exceeds the 500-line instruction budget"
  fi

  while IFS= read -r reference; do
    validate_reference "$skill_dir" "$skill_file" "$reference"
  done < <(extract_markdown_links "$skill_file")

  while IFS= read -r reference; do
    validate_reference "$skill_dir" "$skill_file" "$reference"
  done < <(
    grep -Eo '(assets|references|scripts|templates)/[A-Za-z0-9._/-]+' \
      "$skill_file" | sort -u || true
  )
}

if [ ! -d "$SKILLS_DIR" ] || [ ! -f "$CATALOG_FILE" ] ||
  [ ! -f "$SETUP_FILE" ]; then
  printf 'error: repository skill catalog is incomplete: %s\n' "$REPO_DIR" >&2
  exit 1
fi

skill_names=()
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_dir="${skill_dir%/}"
  skill_names+=("${skill_dir##*/}")
  validate_skill "$skill_dir"
done

printf '%s\n' "${skill_names[@]}" | LC_ALL=C sort \
  > "$TMP_ROOT/directories"
sed -n 's/^### `\([^`]*\)`$/\1/p' "$CATALOG_FILE" \
  | LC_ALL=C sort > "$TMP_ROOT/catalog"
awk '
  /^GLOBAL_SKILLS=\(/ { in_array = 1; next }
  in_array && /^\)/ { exit }
  in_array {
    value = $0
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    if (value != "") print value
  }
' "$SETUP_FILE" | LC_ALL=C sort > "$TMP_ROOT/global-skills"

if ! cmp -s "$TMP_ROOT/directories" "$TMP_ROOT/catalog"; then
  report_error "skills/README.md catalog does not match skill directories"
  diff -u "$TMP_ROOT/directories" "$TMP_ROOT/catalog" >&2 || true
fi
if ! cmp -s "$TMP_ROOT/directories" "$TMP_ROOT/global-skills"; then
  report_error "setup.sh GLOBAL_SKILLS does not match skill directories"
  diff -u "$TMP_ROOT/directories" "$TMP_ROOT/global-skills" >&2 || true
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

printf 'skill validation passed: %d skills\n' "${#skill_names[@]}"
