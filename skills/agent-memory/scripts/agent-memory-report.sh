#!/usr/bin/env bash
#
# agent-memory-report.sh — read-only report on a file-based memory store.
#
# Surfaces the levers from the agent-memory skill: approximate token cost,
# the largest files (split candidates), entries missing tiering front
# matter, and [[links]] with no matching entry. Makes no changes.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-memory-report.sh [MEMORY_DIR]

Read-only report on a file-based memory store (makes no changes).

  MEMORY_DIR   memory directory tree (default: current directory)
  -h, --help   show this help

Reports: file, router, and archive counts; approximate total tokens
(chars/4); the largest files; entries missing load/status/type front
matter; and [[links]] with no matching entry name.
EOF
}

# Print the YAML frontmatter block (the content between the first two
# '---' fences). Some hosts normalize an entry's front matter on save
# and nest most fields under a 'metadata:' map; scoping key lookups to
# the frontmatter and allowing any indentation handles both the flat
# top-level layout and the nested layout.
frontmatter() {
  awk '
    NR==1 && $0=="---" { inblock=1; next }
    inblock && $0=="---" { exit }
    inblock { print }
  ' "$1"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -*)
    echo "error: unknown option: $1" >&2
    exit 1
    ;;
esac
if [ "$#" -gt 1 ]; then
  echo "error: expected at most one memory directory" >&2
  exit 1
fi

dir="${1:-.}"
if [ ! -d "$dir" ]; then
  echo "error: not a directory: $dir" >&2
  exit 1
fi
case "$dir" in
  /) ;;
  */) dir="${dir%/}" ;;
esac

temp_dir="${TMPDIR:-/tmp}"
if [ ! -d "$temp_dir" ]; then
  echo "error: temporary directory does not exist: $temp_dir" >&2
  exit 1
fi

file_list=""
sorted_file_list=""
cleanup() {
  [ -z "$file_list" ] || rm -f "$file_list"
  [ -z "$sorted_file_list" ] || rm -f "$sorted_file_list"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

file_list="$(mktemp "$temp_dir/agent-memory-report-files.XXXXXX")"
sorted_file_list="$(mktemp "$temp_dir/agent-memory-report-sorted.XXXXXX")"

if ! find "$dir" -type f -name '*.md' -print > "$file_list"; then
  echo "error: could not scan memory directory: $dir" >&2
  exit 1
fi
LC_ALL=C sort "$file_list" > "$sorted_file_list"

files=()
while IFS= read -r file; do
  [ -n "$file" ] && files+=("$file")
done < "$sorted_file_list"
if [ "${#files[@]}" -eq 0 ]; then
  echo "no .md files in: $dir"
  exit 0
fi

display_path() {
  local path="$1"

  case "$path" in
    "$dir"/*) printf '%s\n' "${path#"$dir"/}" ;;
    *) printf '%s\n' "$(basename "$path")" ;;
  esac
}

frontmatter_field() {
  local file="$1"
  local field="$2"

  frontmatter "$file" |
    sed -nE "s/^[[:space:]]*${field}:[[:space:]]*(.*)$/\\1/p" |
    sed -n '1p'
}

router_count=0
archive_count=0
for f in "${files[@]}"; do
  if [ "$(basename "$f")" = "MEMORY.md" ]; then
    router_count=$((router_count + 1))
  elif [ "$(frontmatter_field "$f" load)" = "archive" ]; then
    archive_count=$((archive_count + 1))
  fi
done

total_chars=$(cat "${files[@]}" | wc -c)
echo "store:           $dir"
echo "files:           ${#files[@]}"
echo "entries:         $(( ${#files[@]} - router_count ))"
echo "router files:    $router_count"
echo "archive entries: $archive_count"
echo "approx tokens:   $(( total_chars / 4 ))  (chars/4 estimate)"
echo

echo "largest entries (approx tokens) — split candidates:"
for f in "${files[@]}"; do
  c=$(wc -c < "$f")
  printf '%8d  %s\n' "$(( c / 4 ))" "$(display_path "$f")"
done | sort -rn | sed -n '1,10p'
echo

echo "entries missing tiering front matter (load / status / type):"
missing=0
for f in "${files[@]}"; do
  base=$(basename "$f")
  [ "$base" = "MEMORY.md" ] && continue
  for field in load status type; do
    if ! frontmatter "$f" | grep -qE "^[[:space:]]*${field}:"; then
      printf '  %-44s missing: %s\n' "$(display_path "$f")" "$field"
      missing=1
    fi
  done
done
[ "$missing" -eq 0 ] && echo "  (none)"
echo

echo "unresolved [[links]] (no entry has a matching name: slug):"
slugs=$(for f in "${files[@]}"; do frontmatter "$f"; done \
        | grep -oE '^[[:space:]]*name:[[:space:]]*[A-Za-z0-9_-]+' \
        | sed -E 's/^[[:space:]]*name:[[:space:]]*//' | sort -u || true)
found_any=0
for f in "${files[@]}"; do
  targets=$(grep -oE '\[\[[A-Za-z0-9_-]+\]\]' "$f" 2>/dev/null \
            | sed -E 's/\[\[|\]\]//g' | sort -u || true)
  [ -z "$targets" ] && continue
  while IFS= read -r tgt; do
    [ -z "$tgt" ] && continue
    if ! printf '%s\n' "$slugs" | grep -qxF "$tgt"; then
      printf '  %-44s -> [[%s]]\n' "$(display_path "$f")" "$tgt"
      found_any=1
    fi
  done <<< "$targets"
done
[ "$found_any" -eq 0 ] && echo "  (none)"
echo "note: unresolved links may be intentional placeholders."
