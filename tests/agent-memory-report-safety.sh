#!/usr/bin/env bash
# Verifies recursive, tier-aware memory reporting and argument failures.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
REPORT="${ROOT_DIR}/skills/agent-memory/scripts/agent-memory-report.sh"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-memory-report.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

expect_fail() {
  local expected="$1"
  shift

  if "$REPORT" "$@" >"$TMP_ROOT/unexpected.out" 2>"$TMP_ROOT/expected.err"; then
    echo "memory report unexpectedly succeeded: $*" >&2
    return 1
  fi
  grep -Fq "$expected" "$TMP_ROOT/expected.err"
}

EMPTY_STORE="$TMP_ROOT/empty"
mkdir -p "$EMPTY_STORE"
test "$("$REPORT" "$EMPTY_STORE")" = "no .md files in: $EMPTY_STORE"

STORE="$TMP_ROOT/store"
mkdir -p "$STORE/area" "$STORE/archive"
printf '# Memory\n' > "$STORE/MEMORY.md"
cat > "$STORE/current.md" <<'EOF'
---
name: current
description: Current state.
type: status
load: always
status: active
---

Current state links to [[decision]].
EOF
cat > "$STORE/area/decision.md" <<'EOF'
---
name: decision
description: Nested decision.
type: decision
load: recall
status: active
---

The decision links to [[history]].
EOF
cat > "$STORE/area/normalized.md" <<'EOF'
---
name: normalized
description: Host-normalized metadata.
metadata:
  type: reference
  load: recall
  status: active
---

Normalized metadata remains valid.
EOF
cat > "$STORE/area/malformed.md" <<'EOF'
---
name: malformed
description: Missing tier fields.
load: recall
---

This entry links to [[missing-entry]].
EOF
cat > "$STORE/archive/history.md" <<'EOF'
---
name: history
description: Archived history.
type: status
load: archive
status: superseded
---

Archived details.
EOF

REPORT_TMP="$TMP_ROOT/report-tmp"
mkdir -p "$REPORT_TMP"
TMPDIR="$REPORT_TMP" "$REPORT" "$STORE" > "$TMP_ROOT/report.out"
test -z "$(find "$REPORT_TMP" -mindepth 1 -print -quit)"
grep -Fq "store:           $STORE" "$TMP_ROOT/report.out"
grep -Fq 'files:           6' "$TMP_ROOT/report.out"
grep -Fq 'entries:         5' "$TMP_ROOT/report.out"
grep -Fq 'router files:    1' "$TMP_ROOT/report.out"
grep -Fq 'archive entries: 1' "$TMP_ROOT/report.out"
grep -Eq '[[:space:]]area/decision\.md$' "$TMP_ROOT/report.out"
grep -Eq '[[:space:]]archive/history\.md$' "$TMP_ROOT/report.out"
grep -Eq 'area/malformed\.md[[:space:]]+missing: status$' \
  "$TMP_ROOT/report.out"
grep -Eq 'area/malformed\.md[[:space:]]+missing: type$' \
  "$TMP_ROOT/report.out"
if grep -Fq 'area/normalized.md' "$TMP_ROOT/report.out" &&
  grep -F 'area/normalized.md' "$TMP_ROOT/report.out" | grep -Fq 'missing:'; then
  echo 'normalized metadata was reported as incomplete' >&2
  exit 1
fi
grep -Eq 'area/malformed\.md[[:space:]]+-> \[\[missing-entry\]\]$' \
  "$TMP_ROOT/report.out"
! grep -Fq -- '-> [[decision]]' "$TMP_ROOT/report.out"
! grep -Fq -- '-> [[history]]' "$TMP_ROOT/report.out"

FAIL_BIN="$TMP_ROOT/fail-bin"
FAIL_TMP="$TMP_ROOT/fail-tmp"
mkdir -p "$FAIL_BIN" "$FAIL_TMP"
printf '#!/bin/sh\nexit 19\n' > "$FAIL_BIN/sort"
chmod +x "$FAIL_BIN/sort"
if PATH="$FAIL_BIN:$PATH" TMPDIR="$FAIL_TMP" "$REPORT" "$STORE" \
  >"$TMP_ROOT/sort-failure.out" 2>"$TMP_ROOT/sort-failure.err"; then
  echo 'memory report unexpectedly survived a sort failure' >&2
  exit 1
fi
test -z "$(find "$FAIL_TMP" -mindepth 1 -print -quit)"

expect_fail 'error: not a directory:' "$TMP_ROOT/missing"
expect_fail 'error: unknown option: --invalid' --invalid
expect_fail 'error: expected at most one memory directory' "$STORE" extra

printf 'agent memory report safety tests passed\n'
