#!/usr/bin/env bash
# Verifies compact project policy completeness and byte limits.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-context-tests.XXXXXX)"
TEST_HOME="$TMP_ROOT/home"

trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TEST_HOME"
git config --file "$TEST_HOME/.gitconfig" user.name "Test User"
git config --file "$TEST_HOME/.gitconfig" user.email "test@example.com"

expected_rule_count() {
  case "$1:$2" in
    minimal:none) printf '9' ;;
    minimal:date) printf '11' ;;
    minimal:version) printf '13' ;;
    codebase:none) printf '18' ;;
    codebase:date) printf '20' ;;
    codebase:version) printf '22' ;;
    released:none) printf '19' ;;
    released:date) printf '21' ;;
    released:version) printf '22' ;;
    *) return 1 ;;
  esac
}

assert_compact_policy() {
  local repo="$1"
  local expected_count="$2"
  local context="$repo/AGENTS.md"
  local bytes count relative_path

  bytes="$(wc -c < "$context")"
  test "$bytes" -le 24576
  grep -Fq '## Agent Guidelines' "$context"
  grep -Fq '### Core Policy' "$context"
  grep -Fq '### Rule Router' "$context"
  test "$(grep -Fxc '#### Hard Constraints' "$context")" -eq 5
  grep -Fq 'global instructions are not a' "$context"
  grep -Fxq 'context_rules=compact' "$repo/.agent-guidelines/config"

  count="$(awk -F'|' '$2 ~ /^ [a-z0-9]+(-[a-z0-9]+)* $/ { count++ } END { print count + 0 }' "$context")"
  test "$count" -eq "$expected_count"
  while IFS= read -r relative_path; do
    test -f "$repo/$relative_path"
  done < <(awk -F'`' '$0 ~ /^\| [a-z0-9]+(-[a-z0-9]+)* \|/ { print $2 }' "$context")
}

for profile in minimal codebase released; do
  for changelog in none date version; do
    repo="$TMP_ROOT/$profile-$changelog"
    HOME="$TEST_HOME" "$ROOT_DIR/project-setup.sh" \
      --profile "$profile" --changelog "$changelog" \
      --context-rules compact --harness codex "$repo" >/dev/null
    assert_compact_policy \
      "$repo" "$(expected_rule_count "$profile" "$changelog")"
  done
done

# Every accepted legacy mode is normalized into the self-contained format.
LEGACY_REPO="$TMP_ROOT/legacy-mode"
HOME="$TEST_HOME" "$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --context-rules full --harness codex \
  "$LEGACY_REPO" >"$TMP_ROOT/legacy.out"
grep -Fq 'context rules mode full migrated to compact' "$TMP_ROOT/legacy.out"
assert_compact_policy "$LEGACY_REPO" 9

# A malformed global context cannot change project policy completeness.
PARTIAL_HOME="$TMP_ROOT/partial-home"
mkdir -p "$PARTIAL_HOME/.codex"
git config --file "$PARTIAL_HOME/.gitconfig" user.name "Test User"
git config --file "$PARTIAL_HOME/.gitconfig" user.email "test@example.com"
printf '%s\n' '<!-- BEGIN agent-guidelines project rules -->' \
  > "$PARTIAL_HOME/.codex/AGENTS.md"
PARTIAL_REPO="$TMP_ROOT/partial-global"
HOME="$PARTIAL_HOME" "$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --harness codex \
  "$PARTIAL_REPO" >/dev/null
assert_compact_policy "$PARTIAL_REPO" 9
cmp -s "$LEGACY_REPO/AGENTS.md" "$PARTIAL_REPO/AGENTS.md"

# Existing project notes cannot silently push the managed file over its cap.
OVERSIZE_REPO="$TMP_ROOT/oversize"
HOME="$TEST_HOME" "$ROOT_DIR/project-setup.sh" \
  --profile minimal --changelog none --harness codex \
  "$OVERSIZE_REPO" >/dev/null
for line in $(seq 1 500); do
  printf 'project note %04d adds stable local context padding\n' "$line"
done >> "$OVERSIZE_REPO/AGENTS.md"
before_hash="$(sha256sum "$OVERSIZE_REPO/AGENTS.md")"
if HOME="$TEST_HOME" "$ROOT_DIR/project-setup.sh" \
  "$OVERSIZE_REPO" >"$TMP_ROOT/oversize.out" 2>"$TMP_ROOT/oversize.err"; then
  echo "oversize project context unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'project context exceeds 24576 bytes' "$TMP_ROOT/oversize.err"
test "$(sha256sum "$OVERSIZE_REPO/AGENTS.md")" = "$before_hash"

printf 'project context compatibility tests passed\n'
