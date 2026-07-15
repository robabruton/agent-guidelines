#!/usr/bin/env bash
# Verifies tracked rule and skill copies carry the required license notice.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-copy-license.XXXXXX)"
NOTICE_FILENAME="POLYFORM-NONCOMMERCIAL.txt"
NOTICE_ASSET="${ROOT_DIR}/skills/project-setup/assets/polyform-noncommercial-notice.txt"
NOTICE_TEXT='Governed by the PolyForm Noncommercial License 1.0.0. Terms: https://polyformproject.org/licenses/noncommercial/1.0.0'

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Copy License Test"
git config --global user.email "copy-license@example.invalid"

assert_licensed_copy() {
  local source="$1"
  local target="$2"
  local stage

  test -f "$target/$NOTICE_FILENAME"
  test ! -L "$target/$NOTICE_FILENAME"
  cmp -s "$NOTICE_ASSET" "$target/$NOTICE_FILENAME"

  stage="$(mktemp -d "${TMP_ROOT}/snapshot.XXXXXX")"
  cp -a "$target" "$stage/snapshot"
  rm "$stage/snapshot/$NOTICE_FILENAME"
  diff -qr "$source" "$stage/snapshot" >/dev/null
  rm -rf "$stage"
}

assert_notice_precedes_summary() {
  local output="$1"
  local notice_line summary_line

  notice_line="$(grep -nFx "$NOTICE_TEXT" "$output" |
    sed -n '1s/:.*//p')"
  summary_line="$(grep -nFx 'Project setup summary' "$output" |
    sed -n '1s/:.*//p')"
  test -n "$notice_line"
  test -n "$summary_line"
  test "$notice_line" -lt "$summary_line"
}

expect_fail() {
  if "$@" >"${TMP_ROOT}/unexpected.out" 2>"${TMP_ROOT}/expected.err"; then
    echo "expected command to fail: $*" >&2
    return 1
  fi
}

test "$(cat "$NOTICE_ASSET")" = "$NOTICE_TEXT"

# A full tracked rule snapshot contains the canonical notice and commits it.
RULE_REPO="${TMP_ROOT}/rule-copy"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --rules-source copy \
  "$RULE_REPO" >"${TMP_ROOT}/rule-copy.out"
assert_notice_precedes_summary "${TMP_ROOT}/rule-copy.out"
assert_licensed_copy \
  "$ROOT_DIR/rules" "$RULE_REPO/.agent-guidelines/rules"
git -C "$RULE_REPO" ls-files --error-unmatch \
  ".agent-guidelines/rules/$NOTICE_FILENAME" >/dev/null
! git -C "$RULE_REPO" check-ignore --quiet --no-index \
  ".agent-guidelines/rules/$NOTICE_FILENAME"
test -z "$(git -C "$RULE_REPO" status --short)"

# A partial skill selection receives the same notice in every required tree.
SKILL_REPO="${TMP_ROOT}/skill-copy"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none \
  --rules-source symlink --skills-source copy \
  --harness claude --harness codex --include-skill explain \
  "$SKILL_REPO" >"${TMP_ROOT}/skill-copy.out"
assert_notice_precedes_summary "${TMP_ROOT}/skill-copy.out"
test "$(grep -Fxc "$NOTICE_TEXT" "${TMP_ROOT}/skill-copy.out")" -eq 1
for root in .claude/skills .agents/skills; do
  assert_licensed_copy \
    "$ROOT_DIR/skills/explain" "$SKILL_REPO/$root/explain"
  git -C "$SKILL_REPO" ls-files --error-unmatch \
    "$root/explain/$NOTICE_FILENAME" >/dev/null
  ! git -C "$SKILL_REPO" check-ignore --quiet --no-index \
    "$root/explain/$NOTICE_FILENAME"
done
test ! -e "$SKILL_REPO/.agent-guidelines/rules/$NOTICE_FILENAME"
test -z "$(git -C "$SKILL_REPO" status --short)"

# Exact snapshots from the notice-free format migrate by adding only the
# missing notice, and a no-flag rerun remains idempotent.
rm "$RULE_REPO/.agent-guidelines/rules/$NOTICE_FILENAME"
diff -qr "$ROOT_DIR/rules" \
  "$RULE_REPO/.agent-guidelines/rules" >/dev/null
"${ROOT_DIR}/project-setup.sh" "$RULE_REPO" \
  >"${TMP_ROOT}/rule-migration.out"
assert_licensed_copy \
  "$ROOT_DIR/rules" "$RULE_REPO/.agent-guidelines/rules"
grep -Fq '.agent-guidelines/rules copy-mode license notice' \
  "${TMP_ROOT}/rule-migration.out"
test -z "$(git -C "$RULE_REPO" status --short)"

for root in .claude/skills .agents/skills; do
  rm "$SKILL_REPO/$root/explain/$NOTICE_FILENAME"
  diff -qr "$ROOT_DIR/skills/explain" \
    "$SKILL_REPO/$root/explain" >/dev/null
done
"${ROOT_DIR}/project-setup.sh" "$SKILL_REPO" \
  >"${TMP_ROOT}/skill-migration.out"
for root in .claude/skills .agents/skills; do
  assert_licensed_copy \
    "$ROOT_DIR/skills/explain" "$SKILL_REPO/$root/explain"
  grep -Fq "$root/explain copy-mode license notice" \
    "${TMP_ROOT}/skill-migration.out"
done
test -z "$(git -C "$SKILL_REPO" status --short)"

"${ROOT_DIR}/project-setup.sh" "$SKILL_REPO" \
  >"${TMP_ROOT}/skill-rerun.out"
test -z "$(git -C "$SKILL_REPO" status --short)"

# An incorrect notice is a modified snapshot, so setup fails unchanged.
WRONG_NOTICE_REPO="$RULE_REPO"
printf 'incorrect notice\n' \
  >"$WRONG_NOTICE_REPO/.agent-guidelines/rules/$NOTICE_FILENAME"
cp -a "$WRONG_NOTICE_REPO" "${TMP_ROOT}/wrong-notice.before"
expect_fail "${ROOT_DIR}/project-setup.sh" "$WRONG_NOTICE_REPO"
grep -Fq '.agent-guidelines/rules is not an exact managed snapshot' \
  "${TMP_ROOT}/expected.err"
diff -qr "$WRONG_NOTICE_REPO" \
  "${TMP_ROOT}/wrong-notice.before" >/dev/null

printf 'project copy license safety tests passed\n'
