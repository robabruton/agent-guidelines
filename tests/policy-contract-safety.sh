#!/usr/bin/env bash
# Verifies review-only policy contracts that do not have executable hooks.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Requires a rule to retain an approved policy statement.
assert_contract() {
  local rule_file="$1"
  local expected="$2"
  local normalized

  normalized="$(tr '\n' ' ' < "${ROOT_DIR}/${rule_file}" | tr -s '[:space:]' ' ')"
  if ! grep -Fq "$expected" <<< "$normalized"; then
    printf 'missing policy contract in %s: %s\n' "$rule_file" "$expected" >&2
    exit 1
  fi
}

bash "${ROOT_DIR}/scripts/generate-hook-policy.sh" --check

assert_contract rules/testing.md \
  "Fixed dates are appropriate for parsing known formats, boundary cases, snapshots, and other semantics tied to that exact value."
assert_contract rules/testing.md \
  "Never make correctness depend on when the suite happens to run."

assert_contract rules/code-quality.md \
  "A suppression is acceptable only when the diagnostic originates outside the code's control and no source fix exists."
assert_contract rules/code-quality.md \
  "Blanket, file-wide, and unexplained suppressions are forbidden."

assert_contract rules/agent-conduct.md \
  "For unowned or user data, back up the entire target"
assert_contract rules/agent-conduct.md \
  "Owned generated data may be atomically replaced without a persistent backup only when both ownership and the exact current state are verified."
assert_contract rules/agent-conduct.md \
  "An ownership or state mismatch always stops without mutation."

printf 'policy contract safety tests passed\n'
