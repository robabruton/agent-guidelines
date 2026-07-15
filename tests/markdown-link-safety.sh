#!/usr/bin/env bash
# Verifies tracked Markdown link resolution and template exclusions.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CHECKER="${ROOT_DIR}/scripts/check-markdown-links.sh"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-markdown-links.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  local name="$1"
  local fixture="$TMP_ROOT/$name"

  mkdir -p "$fixture/docs" "$fixture/skills/example/templates"
  git -C "$fixture" init -q --initial-branch=main
  printf '# Guide\n' > "$fixture/docs/guide.md"
  printf '# Linked file\n' > "$fixture/docs/linked file.md"
  printf '%s\n' \
    '# Project' \
    '' \
    '[Guide](docs/guide.md) and [spaced](<docs/linked file.md>).' \
    '[Section](docs/guide.md#guide) and [site](https://example.com).' \
    > "$fixture/README.md"
  printf '%s\n' '- [Title](missing-output.md)' \
    > "$fixture/skills/example/templates/INDEX.md"
  git -C "$fixture" add .
  printf '%s\n' "$fixture"
}

expect_failure() {
  local fixture="$1"
  local expected="$2"
  local label="$3"

  if "$CHECKER" "$fixture" >"$TMP_ROOT/$label.out" \
    2>"$TMP_ROOT/$label.err"; then
    echo "Markdown validation unexpectedly succeeded: $label" >&2
    return 1
  fi
  grep -Fq "$expected" "$TMP_ROOT/$label.err"
}

fixture="$(new_fixture valid)"
"$CHECKER" "$fixture" > "$TMP_ROOT/valid.out"
grep -Fq 'Markdown link validation passed: 4 files, 3 internal links' \
  "$TMP_ROOT/valid.out"

fixture="$(new_fixture missing)"
printf '[Missing](docs/missing.md)\n' >> "$fixture/README.md"
expect_failure "$fixture" \
  'README.md has a missing link target: docs/missing.md' missing

fixture="$(new_fixture escape)"
printf '# Outside\n' > "$TMP_ROOT/outside.md"
printf '[Outside](../outside.md)\n' >> "$fixture/README.md"
expect_failure "$fixture" \
  'README.md links outside the repository: ../outside.md' escape

mkdir -p "$TMP_ROOT/not-a-repository"
expect_failure "$TMP_ROOT/not-a-repository" 'error: not a Git repository:' \
  not-a-repository

printf 'Markdown link safety tests passed\n'
