#!/usr/bin/env bash
# Verifies ownership preflight and rollback for generated hook assets.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-hook-generation.XXXXXX)"
FIXTURE="${TMP_ROOT}/repo"

trap 'rm -rf "$TMP_ROOT"' EXIT

# Requires a command to fail.
expect_fail() {
  if "$@" >/dev/null 2>&1; then
    printf 'expected failure but succeeded: %s\n' "$*" >&2
    exit 1
  fi
}

# Rewrites one known generator token inside the disposable fixture.
rewrite_generator() {
  local from="$1"
  local to="$2"
  local rewritten="${TMP_ROOT}/generator.rewritten"

  sed "s/${from}/${to}/g" "${FIXTURE}/scripts/generate-hook-policy.sh" \
    > "$rewritten"
  if cmp -s "${FIXTURE}/scripts/generate-hook-policy.sh" "$rewritten"; then
    printf 'generator token not found: %s\n' "$from" >&2
    exit 1
  fi
  mv "$rewritten" "${FIXTURE}/scripts/generate-hook-policy.sh"
  chmod +x "${FIXTURE}/scripts/generate-hook-policy.sh"
}

mkdir -p "${FIXTURE}/scripts" \
  "${FIXTURE}/skills/project-setup/assets"
cp -p "${ROOT_DIR}/scripts/generate-hook-policy.sh" "${FIXTURE}/scripts/"
cp -a "${ROOT_DIR}/skills/project-setup/assets/hooks" \
  "${FIXTURE}/skills/project-setup/assets/hooks"

git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.name "Test User"
git -C "$FIXTURE" config user.email "test@example.invalid"
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -q -m "test: seed generator fixture"

# A clean tracked asset set can be regenerated and checked repeatedly.
rewrite_generator "Plain POSIX sh" "strict POSIX sh"
bash "${FIXTURE}/scripts/generate-hook-policy.sh" >/dev/null
bash "${FIXTURE}/scripts/generate-hook-policy.sh" --check >/dev/null
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -q -m "test: record strict fixture"

# A changed generated target stops the entire pass before any write.
printf '\nuser-managed edit\n' \
  >> "${FIXTURE}/skills/project-setup/assets/hooks/pre-commit-banned-phrases"
rewrite_generator "strict POSIX sh" "portable POSIX sh"
cp -a "${FIXTURE}/skills/project-setup/assets/hooks" \
  "${TMP_ROOT}/dirty-snapshot"
expect_fail bash "${FIXTURE}/scripts/generate-hook-policy.sh"
diff -qr "${TMP_ROOT}/dirty-snapshot" \
  "${FIXTURE}/skills/project-setup/assets/hooks" >/dev/null

# Restore the disposable fixture, then establish another clean baseline.
git -C "$FIXTURE" show \
  :skills/project-setup/assets/hooks/pre-commit-banned-phrases \
  > "${FIXTURE}/skills/project-setup/assets/hooks/pre-commit-banned-phrases"
bash "${FIXTURE}/scripts/generate-hook-policy.sh" >/dev/null
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -q -m "test: record portable fixture"

# A failure during the write loop restores every target already replaced.
rewrite_generator "portable POSIX sh" "validated POSIX sh"
cp -a "${FIXTURE}/skills/project-setup/assets/hooks" \
  "${TMP_ROOT}/rollback-snapshot"
mkdir -p "${TMP_ROOT}/bin"
cat > "${TMP_ROOT}/bin/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
destination="${!#}"
case "$destination" in
  "${HOOK_TARGET_DIR}"/*)
    count=0
    if [ -f "$COUNT_FILE" ]; then
      read -r count < "$COUNT_FILE"
    fi
    count=$((count + 1))
    printf '%s\n' "$count" > "$COUNT_FILE"
    if [ "$count" -eq 2 ]; then
      exit 1
    fi
    ;;
esac
exec "$REAL_MV" "$@"
EOF
chmod +x "${TMP_ROOT}/bin/mv"

expect_fail env \
  PATH="${TMP_ROOT}/bin:${PATH}" \
  REAL_MV="$(command -v mv)" \
  COUNT_FILE="${TMP_ROOT}/mv-count" \
  HOOK_TARGET_DIR="${FIXTURE}/skills/project-setup/assets/hooks" \
  bash "${FIXTURE}/scripts/generate-hook-policy.sh"
diff -qr "${TMP_ROOT}/rollback-snapshot" \
  "${FIXTURE}/skills/project-setup/assets/hooks" >/dev/null

bash "${FIXTURE}/scripts/generate-hook-policy.sh" >/dev/null
bash "${FIXTURE}/scripts/generate-hook-policy.sh" --check >/dev/null

printf 'hook policy generation safety tests passed\n'
