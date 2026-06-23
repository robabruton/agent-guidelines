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

  MEMORY_DIR   directory of *.md memory files (default: current directory)
  -h, --help   show this help

Reports: file count, approximate total tokens (chars/4), the largest
files, entries missing load/status/type front matter, and [[links]] with
no matching entry name.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

dir="${1:-.}"
if [ ! -d "$dir" ]; then
  echo "error: not a directory: $dir" >&2
  exit 1
fi

shopt -s nullglob
files=("$dir"/*.md)
if [ "${#files[@]}" -eq 0 ]; then
  echo "no .md files in: $dir"
  exit 0
fi

total_chars=$(cat "${files[@]}" | wc -c)
echo "store:           $dir"
echo "files:           ${#files[@]}"
echo "approx tokens:   $(( total_chars / 4 ))  (chars/4 estimate)"
echo

echo "largest entries (approx tokens) — split candidates:"
for f in "${files[@]}"; do
  c=$(wc -c < "$f")
  printf '%8d  %s\n' "$(( c / 4 ))" "$(basename "$f")"
done | sort -rn | head -10
echo

echo "entries missing tiering front matter (load / status / type):"
missing=0
for f in "${files[@]}"; do
  base=$(basename "$f")
  [ "$base" = "MEMORY.md" ] && continue
  for field in load status type; do
    if ! grep -qE "^${field}:" "$f"; then
      printf '  %-44s missing: %s\n' "$base" "$field"
      missing=1
    fi
  done
done
[ "$missing" -eq 0 ] && echo "  (none)"
echo

echo "unresolved [[links]] (no entry has a matching name: slug):"
slugs=$(grep -hoE '^name:[[:space:]]*[A-Za-z0-9_-]+' "${files[@]}" 2>/dev/null \
        | sed -E 's/^name:[[:space:]]*//' | sort -u || true)
found_any=0
for f in "${files[@]}"; do
  targets=$(grep -oE '\[\[[A-Za-z0-9_-]+\]\]' "$f" 2>/dev/null \
            | sed -E 's/\[\[|\]\]//g' | sort -u || true)
  [ -z "$targets" ] && continue
  while IFS= read -r tgt; do
    [ -z "$tgt" ] && continue
    if ! printf '%s\n' "$slugs" | grep -qxF "$tgt"; then
      printf '  %-44s -> [[%s]]\n' "$(basename "$f")" "$tgt"
      found_any=1
    fi
  done <<< "$targets"
done
[ "$found_any" -eq 0 ] && echo "  (none)"
echo "note: a link to a not-yet-written slug may be intentional."
