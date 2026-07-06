#!/usr/bin/env bash
# Verifies the git hook snippets installed by project-setup.sh in a
# temporary repository: main-branch guard, conventional commit guard,
# attribution guards, merge exemptions, and the pre-push branch-name
# guard. Flagged phrases used as negative fixtures are assembled from
# fragments at runtime so this file never trips the staged guard.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-hooks.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

REPO="${TMP_ROOT}/repo"
REMOTE="${TMP_ROOT}/remote.git"

expect_fail() {
  if "$@" >/dev/null 2>&1; then
    echo "expected failure but succeeded: $*" >&2
    exit 1
  fi
}

"${ROOT_DIR}/project-setup.sh" --profile minimal --changelog none "$REPO" > /dev/null

cd "$REPO" || exit 1

# Hook snippets must be valid POSIX sh. dash is the strictest common
# /bin/sh, so use it for the syntax check when it is installed.
for hook in pre-commit commit-msg pre-push; do
  sh -n ".git/hooks/${hook}"
  if command -v dash >/dev/null 2>&1; then
    dash -n ".git/hooks/${hook}"
  fi
done

# Main-branch guard: authored commits on main are blocked.
printf 'a\n' > file-a.txt
git add file-a.txt
expect_fail git commit -m "feat: add file a"

git checkout -q -b feat/hook-check

# Conventional guard: a valid subject passes.
git commit -q -m "feat: add file a"

# Conventional guard: a non-conventional subject fails.
printf 'b\n' > file-b.txt
git add file-b.txt
expect_fail git commit -m "Add file b"

# Conventional guard: a subject over 60 characters fails.
long_subject="feat: $(printf 'x%.0s' {1..60})"
expect_fail git commit -m "$long_subject"

# Conventional guard: multibyte characters are counted as characters,
# not bytes. This subject is 57 characters but 98 bytes in UTF-8.
if [ "$(locale charmap 2>/dev/null)" = "UTF-8" ]; then
  accents="$(printf 'é%.0s' {1..40})"
  git commit -q -m "feat: café notes ${accents}"
  printf 'b\n' >> file-b.txt
  git add file-b.txt
fi

# Attribution guard (commit message): a tool-authorship trailer fails.
trailer_key="Co-Authored""-By"
expect_fail git commit -m "feat: add file b" -m "${trailer_key}: Bot <bot@example.com>"

# Commit file-b cleanly so later steps start from a clean tree.
git commit -q -m "feat: add file b"

# Attribution guard (staged content): trailer and adjective shapes fail.
printf '%s an AI assistant\n' "Written""-by:" > file-c.txt
git add file-c.txt
expect_fail git commit -m "feat: add file c"
git reset -q -- file-c.txt
rm -f file-c.txt

printf '%s helper code\n' "ai""-generated" > file-d.txt
git add file-d.txt
expect_fail git commit -m "feat: add file d"
git reset -q -- file-d.txt
rm -f file-d.txt

# Merge exemption: a --no-ff merge into main passes both the
# main-branch guard and the conventional guard.
git checkout -q main
git merge -q --no-ff -m "Merge branch 'feat/hook-check'" feat/hook-check

# Branch-name guard: pushes are validated against the pushed refs.
git init -q --bare "$REMOTE"
git remote add origin "$REMOTE"

git push -q origin main

git branch badname
expect_fail git push origin badname

# The pushed ref is what matters, not the checked-out branch.
git checkout -q badname
git push -q origin feat/hook-check
git checkout -q main

# Deleting a badly named remote branch is allowed.
git -C "$REMOTE" update-ref refs/heads/badname "$(git rev-parse main)"
git push -q origin :badname

# Tags are not name-checked.
git tag v0.0.1
git push -q origin v0.0.1

printf 'hooks smoke tests passed\n'
