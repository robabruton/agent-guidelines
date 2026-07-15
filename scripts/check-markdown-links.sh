#!/usr/bin/env bash
# Verifies that relative links in tracked Markdown resolve inside the repository.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-markdown-links.sh [REPOSITORY]

Validate relative links in tracked Markdown files. Template directories are
excluded because their links are output placeholders.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -*)
    printf 'error: unknown option: %s\n' "$1" >&2
    exit 1
    ;;
esac
if [ "$#" -gt 1 ]; then
  echo 'error: expected at most one repository path' >&2
  exit 1
fi

REPO_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
if [ ! -d "$REPO_DIR" ] ||
  ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'error: not a Git repository: %s\n' "$REPO_DIR" >&2
  exit 1
fi
REPO_DIR="$(cd "$REPO_DIR" && pwd -P)"

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

fail=0
file_count=0
link_count=0
while IFS= read -r -d '' relative_file; do
  file_count=$((file_count + 1))
  case "$relative_file" in
    */templates/*) continue ;;
  esac

  file="$REPO_DIR/$relative_file"
  while IFS= read -r target; do
    case "$target" in
      ""|\#*|http://*|https://*|mailto:*) continue ;;
    esac

    case "$target" in
      \<*\>)
        target="${target#<}"
        target="${target%>}"
        ;;
      *) target="${target%% *}" ;;
    esac
    target="${target%%#*}"
    [ -n "$target" ] || continue
    link_count=$((link_count + 1))

    case "$target" in
      /*)
        printf 'error: %s has an absolute link: %s\n' \
          "$relative_file" "$target" >&2
        fail=1
        continue
        ;;
    esac

    candidate="$(dirname "$file")/$target"
    if [ ! -e "$candidate" ]; then
      printf 'error: %s has a missing link target: %s\n' \
        "$relative_file" "$target" >&2
      fail=1
      continue
    fi

    resolved="$(physical_path "$candidate")" || {
      printf 'error: %s has an unresolvable link target: %s\n' \
        "$relative_file" "$target" >&2
      fail=1
      continue
    }
    case "$resolved" in
      "$REPO_DIR"|"$REPO_DIR"/*) ;;
      *)
        printf 'error: %s links outside the repository: %s\n' \
          "$relative_file" "$target" >&2
        fail=1
        ;;
    esac
  done < <(extract_markdown_links "$file")
done < <(git -C "$REPO_DIR" ls-files -z '*.md')

if [ "$fail" -ne 0 ]; then
  exit 1
fi

printf 'Markdown link validation passed: %d files, %d internal links\n' \
  "$file_count" "$link_count"
