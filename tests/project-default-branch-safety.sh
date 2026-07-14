#!/usr/bin/env bash
# Verifies project setup preserves and consistently enforces default branches.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-project-default.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="${TMP_ROOT}/home"
mkdir -p "$HOME"
git config --global user.name "Project Default Test"
git config --global user.email "project-default@example.invalid"

init_repo() {
  local path="$1"
  local branch="$2"

  mkdir -p "$path"
  git -C "$path" init -q -b "$branch"
  printf 'seed\n' > "$path/seed.txt"
  git -C "$path" add seed.txt
  git -C "$path" commit -q -m "chore: seed fixture"
}

expect_precommit_failure() {
  local repo="$1"

  if (cd "$repo" && .git/hooks/pre-commit) >/dev/null 2>&1; then
    echo "default-branch pre-commit unexpectedly succeeded: $repo" >&2
    return 1
  fi
}

expect_merge_precommit_success() {
  local repo="$1"
  local merge_head

  merge_head="$(git -C "$repo" rev-parse --git-path MERGE_HEAD)"
  case "$merge_head" in
    /*) ;;
    *) merge_head="$repo/$merge_head" ;;
  esac
  git -C "$repo" rev-parse HEAD > "$merge_head"
  if ! (cd "$repo" && .git/hooks/pre-commit) >/dev/null 2>&1; then
    rm -f "$merge_head"
    echo "default-branch merge pre-commit unexpectedly failed: $repo" >&2
    return 1
  fi
  rm -f "$merge_head"
}

expect_prepush() {
  local expected_exit="$1"
  local repo="$2"
  local branch="$3"
  local sha
  local actual_exit

  sha="$(git -C "$repo" rev-parse HEAD)"
  set +e
  printf 'refs/heads/%s %s refs/heads/%s %040d\n' \
    "$branch" "$sha" "$branch" 0 |
    (cd "$repo" && .git/hooks/pre-push origin fixture) \
      >"${TMP_ROOT}/prepush.out" 2>"${TMP_ROOT}/prepush.err"
  actual_exit=$?
  set -e
  if [ "$actual_exit" -ne "$expected_exit" ]; then
    cat "${TMP_ROOT}/prepush.err" >&2
    echo "pre-push exit $actual_exit, expected $expected_exit: $branch" >&2
    return 1
  fi
}

# Existing master and third-name repositories keep their only local branch as
# the default. Both hooks consume the same stored value.
MASTER_REPO="${TMP_ROOT}/master-repo"
init_repo "$MASTER_REPO" master
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$MASTER_REPO" > "${TMP_ROOT}/master.out"
grep -Fxq 'default_branch=master' \
  "$MASTER_REPO/.agent-guidelines/config"
grep -Fq 'Default branch policy: master' "${TMP_ROOT}/master.out"
grep -Fq 'Default branch: master' "${TMP_ROOT}/master.out"
expect_precommit_failure "$MASTER_REPO"
expect_merge_precommit_success "$MASTER_REPO"
expect_prepush 0 "$MASTER_REPO" master
expect_prepush 0 "$MASTER_REPO" feat/valid-work
expect_prepush 1 "$MASTER_REPO" invalid-work

STABLE_REPO="${TMP_ROOT}/stable-repo"
init_repo "$STABLE_REPO" stable
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$STABLE_REPO" > "${TMP_ROOT}/stable.out"
grep -Fxq 'default_branch=stable' \
  "$STABLE_REPO/.agent-guidelines/config"
expect_precommit_failure "$STABLE_REPO"
expect_merge_precommit_success "$STABLE_REPO"
expect_prepush 0 "$STABLE_REPO" stable

# New repositories accept an explicit default without renaming it later.
TRUNK_REPO="${TMP_ROOT}/trunk-repo"
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  --default-branch trunk "$TRUNK_REPO" > "${TMP_ROOT}/trunk.out"
test "$(git -C "$TRUNK_REPO" branch --show-current)" = trunk
grep -Fxq 'default_branch=trunk' "$TRUNK_REPO/.agent-guidelines/config"
expect_precommit_failure "$TRUNK_REPO"
expect_merge_precommit_success "$TRUNK_REPO"
expect_prepush 0 "$TRUNK_REPO" trunk
expect_prepush 1 "$TRUNK_REPO" main

# Multiple branches with a checked-out work branch are ambiguous without local
# remote-HEAD or stored policy. Rejection leaves the repository unchanged.
AMBIGUOUS_REPO="${TMP_ROOT}/ambiguous-repo"
init_repo "$AMBIGUOUS_REPO" main
git -C "$AMBIGUOUS_REPO" branch stable
git -C "$AMBIGUOUS_REPO" checkout -q -b feat/policy-check
cp -a "$AMBIGUOUS_REPO" "${AMBIGUOUS_REPO}.before"
if "${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$AMBIGUOUS_REPO" >"${TMP_ROOT}/ambiguous.out" \
  2>"${TMP_ROOT}/ambiguous.err"; then
  echo "ambiguous default branch unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'default branch is ambiguous; use --default-branch' \
  "${TMP_ROOT}/ambiguous.err"
diff -qr "$AMBIGUOUS_REPO" "${AMBIGUOUS_REPO}.before" >/dev/null

# An explicit choice resolves ambiguity without checkout or rename. Stored
# policy then makes a no-flag rerun deterministic from the work branch.
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  --default-branch main "$AMBIGUOUS_REPO" \
  > "${TMP_ROOT}/ambiguous-explicit.out"
test "$(git -C "$AMBIGUOUS_REPO" branch --show-current)" = feat/policy-check
grep -Fxq 'default_branch=main' \
  "$AMBIGUOUS_REPO/.agent-guidelines/config"
"${ROOT_DIR}/project-setup.sh" "$AMBIGUOUS_REPO" \
  > "${TMP_ROOT}/ambiguous-rerun.out"
test "$(git -C "$AMBIGUOUS_REPO" branch --show-current)" = feat/policy-check
grep -Fxq 'default_branch=main' \
  "$AMBIGUOUS_REPO/.agent-guidelines/config"

# A local remote-HEAD symbolic ref supplies the default when a work branch is
# checked out and multiple local branches exist.
REMOTE_REPO="${TMP_ROOT}/remote-head-repo"
init_repo "$REMOTE_REPO" main
git -C "$REMOTE_REPO" checkout -q -b feat/remote-check
git -C "$REMOTE_REPO" update-ref refs/remotes/origin/main \
  "$(git -C "$REMOTE_REPO" rev-parse main)"
git -C "$REMOTE_REPO" symbolic-ref refs/remotes/origin/HEAD \
  refs/remotes/origin/main
"${ROOT_DIR}/project-setup.sh" \
  --profile minimal --changelog none --context-rules full \
  "$REMOTE_REPO" > "${TMP_ROOT}/remote-head.out"
grep -Fxq 'default_branch=main' "$REMOTE_REPO/.agent-guidelines/config"
test "$(git -C "$REMOTE_REPO" branch --show-current)" = feat/remote-check

# Installed hooks fail closed when their authoritative branch state is absent.
cp -a "$MASTER_REPO/.agent-guidelines/config" \
  "${TMP_ROOT}/master.config.before"
sed '/^default_branch=/d' "$MASTER_REPO/.agent-guidelines/config" \
  > "${TMP_ROOT}/master.config.without-default"
cp "${TMP_ROOT}/master.config.without-default" \
  "$MASTER_REPO/.agent-guidelines/config"
expect_precommit_failure "$MASTER_REPO"
expect_prepush 1 "$MASTER_REPO" master

printf 'project default branch safety tests passed\n'
