#!/usr/bin/env bash
# Verifies skill metadata, catalog parity, and reference validation.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-skill-tests.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  local name="$1"
  local fixture="$TMP_ROOT/$name"

  mkdir -p "$fixture"
  cp -a "$ROOT_DIR/skills" "$fixture/skills"
  cp -a "$ROOT_DIR/setup.sh" "$fixture/setup.sh"
  printf '%s\n' "$fixture"
}

replace_file() {
  local source="$1"
  local target="$2"

  mv "$source" "$target"
}

expect_failure() {
  local fixture="$1"
  local expected="$2"
  local label="$3"

  if "$ROOT_DIR/scripts/validate-skills.sh" "$fixture" \
    >"$TMP_ROOT/$label.out" 2>"$TMP_ROOT/$label.err"; then
    echo "validation unexpectedly succeeded: $label" >&2
    return 1
  fi
  grep -Fq "$expected" "$TMP_ROOT/$label.err"
}

"$ROOT_DIR/scripts/validate-skills.sh" "$ROOT_DIR" >/dev/null

fixture="$(new_fixture name-mismatch)"
sed 's/^name: avr$/name: wrong-name/' "$fixture/skills/avr/SKILL.md" \
  >"$TMP_ROOT/name-mismatch.md"
replace_file "$TMP_ROOT/name-mismatch.md" "$fixture/skills/avr/SKILL.md"
expect_failure "$fixture" 'name does not match directory: wrong-name' \
  name-mismatch

fixture="$(new_fixture description-length)"
long_description="$(awk 'BEGIN { for (i = 0; i < 1025; i++) printf "x" }')"
awk -v description="$long_description" '
  /^description:/ { print "description: " description; next }
  { print }
' "$fixture/skills/avr/SKILL.md" >"$TMP_ROOT/description-length.md"
replace_file "$TMP_ROOT/description-length.md" \
  "$fixture/skills/avr/SKILL.md"
expect_failure "$fixture" 'description exceeds 1024 characters' \
  description-length

fixture="$(new_fixture valid-block-description)"
awk '
  /^description:/ {
    print "description: >-"
    print "  Operate AVR projects with explicit device selection and"
    print "  use this skill for direct firmware work."
    next
  }
  { print }
' "$fixture/skills/avr/SKILL.md" >"$TMP_ROOT/valid-block-description.md"
replace_file "$TMP_ROOT/valid-block-description.md" \
  "$fixture/skills/avr/SKILL.md"
"$ROOT_DIR/scripts/validate-skills.sh" "$fixture" >/dev/null

fixture="$(new_fixture description-block-length)"
awk '
  /^description:/ {
    print "description: >-"
    printf "  "
    for (i = 0; i < 1025; i++) printf "x"
    print ""
    next
  }
  { print }
' "$fixture/skills/avr/SKILL.md" >"$TMP_ROOT/description-block-length.md"
replace_file "$TMP_ROOT/description-block-length.md" \
  "$fixture/skills/avr/SKILL.md"
expect_failure "$fixture" 'description exceeds 1024 characters' \
  description-block-length

fixture="$(new_fixture missing-extension)"
grep -Fv 'when_to_use:' "$fixture/skills/avr/SKILL.md" \
  >"$TMP_ROOT/missing-extension.md"
replace_file "$TMP_ROOT/missing-extension.md" "$fixture/skills/avr/SKILL.md"
expect_failure "$fixture" 'must contain exactly one when_to_use field' \
  missing-extension

fixture="$(new_fixture unsupported-field)"
awk '
  /^when_to_use:/ { print "model: inherit" }
  { print }
' "$fixture/skills/avr/SKILL.md" >"$TMP_ROOT/unsupported-field.md"
replace_file "$TMP_ROOT/unsupported-field.md" \
  "$fixture/skills/avr/SKILL.md"
expect_failure "$fixture" 'unsupported frontmatter field: model' \
  unsupported-field

fixture="$(new_fixture missing-reference)"
sed 's#references/project-layout.md#references/missing.md#' \
  "$fixture/skills/avr/SKILL.md" >"$TMP_ROOT/missing-reference.md"
replace_file "$TMP_ROOT/missing-reference.md" "$fixture/skills/avr/SKILL.md"
expect_failure "$fixture" 'references a missing path: references/missing.md' \
  missing-reference

fixture="$(new_fixture escaping-reference)"
printf '# Outside skill\n' > "$TMP_ROOT/outside-skill.md"
ln -s "$TMP_ROOT/outside-skill.md" \
  "$fixture/skills/avr/references/escape.md"
printf '\n[Escape](references/escape.md)\n' \
  >> "$fixture/skills/avr/SKILL.md"
expect_failure "$fixture" \
  'has an out-of-scope reference: references/escape.md' escaping-reference

fixture="$(new_fixture catalog-drift)"
grep -Fv '### `avr`' "$fixture/skills/README.md" \
  >"$TMP_ROOT/catalog-drift.md"
replace_file "$TMP_ROOT/catalog-drift.md" "$fixture/skills/README.md"
expect_failure "$fixture" \
  'skills/README.md catalog does not match skill directories' catalog-drift

fixture="$(new_fixture global-drift)"
grep -Fv '  avr' "$fixture/setup.sh" >"$TMP_ROOT/global-drift.sh"
replace_file "$TMP_ROOT/global-drift.sh" "$fixture/setup.sh"
expect_failure "$fixture" \
  'setup.sh GLOBAL_SKILLS does not match skill directories' global-drift

printf 'skill validation safety tests passed\n'
