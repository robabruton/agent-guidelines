#!/usr/bin/env bash
# Verifies the git hook snippets installed by project-setup.sh in a
# temporary repository: main-branch guard, conventional commit guard,
# attribution guards, banned-phrase guards over staged content,
# messages, merge bodies, and branch names, merge exemptions, and the
# pre-push branch-name guard. Flagged phrases used as negative
# fixtures are assembled from fragments at runtime so this file never
# trips the staged guards.

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

"${ROOT_DIR}/project-setup.sh" --profile minimal --changelog none \
  --rules-source copy "$REPO" >/dev/null

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

# Direct development authorship uses the same rejection pattern.
direct_attribution="Developed by A""I."
expect_fail git commit -m "feat: add file b" -m "$direct_attribution"

# Commit file-b cleanly so later steps start from a clean tree.
git commit -q -m "feat: add file b"

# Attribution guard (staged content): trailer, direct, artifact, and
# adjective authorship shapes fail.
printf '%s an AI assistant\n' "Written""-by:" > file-c.txt
git add file-c.txt
expect_fail git commit -m "feat: add file c"
git reset -q -- file-c.txt
rm -f file-c.txt

printf '%s\n' "$direct_attribution" > file-d.txt
git add file-d.txt
expect_fail git commit -m "feat: add file d"
git reset -q -- file-d.txt
rm -f file-d.txt

printf 'The code was %s by an assistant.\n' "gene""rated" > file-d2.txt
git add file-d2.txt
expect_fail git commit -m "feat: add file d2"
git reset -q -- file-d2.txt
rm -f file-d2.txt

printf '%s code.\n' "AI""-authored" > file-d3.txt
git add file-d3.txt
expect_fail git commit -m "feat: add file d3"
git reset -q -- file-d3.txt
rm -f file-d3.txt

# Functional integration and product-output descriptions are allowed.
printf 'The app sends prompts to the configured AI provider.\n' > file-d4.txt
printf 'The product exports %s reports.\n' "AI""-generated" >> file-d4.txt
git add file-d4.txt
git commit -q -m "docs: describe functional integration"

# Banned-phrase guard (staged content): forward-looking phrasing
# fails, both as prose and as an unimplemented-work marker.
printf 'support %s soon\n' "coming" > file-e.txt
git add file-e.txt
expect_fail git commit -m "feat: add file e"
git reset -q -- file-e.txt
rm -f file-e.txt

printf '%s implement parser\n' "TO""DO" > file-f.txt
git add file-f.txt
expect_fail git commit -m "feat: add file f"
git reset -q -- file-f.txt
rm -f file-f.txt

# Factual limitations and review notes do not promise unimplemented work.
printf 'The parser accepts JSON input only.\n' > file-g.txt
printf 'Reviewer fol%s: verify the retained size limit.\n' "low-up" \
  >> file-g.txt
git add file-g.txt
git commit -q -m "docs: add file g"

# A present deprecation contract is valid; a speculative replacement is not.
printf 'Option X is deprecated and is removed in version 3.\n' > file-g2.txt
git add file-g2.txt
git commit -q -m "docs: describe deprecation contract"

printf 'A replacement is %s soon.\n' "coming" > file-g3.txt
git add file-g3.txt
expect_fail git commit -m "docs: promise replacement"
git reset -q -- file-g3.txt
rm -f file-g3.txt

# A matching basename outside the two managed rule paths is not exempt.
printf 'banned: %s soon\n' "coming" > no-plans-on-main.md
git add no-plans-on-main.md
expect_fail git commit -m "docs: add phrase list file"
git reset -q -- no-plans-on-main.md
rm -f no-plans-on-main.md

# The repository rule path and installed copy are exact exemptions.
mkdir -p rules
printf 'banned: %s work\n' "future" > rules/no-plans-on-main.md
git add rules/no-plans-on-main.md
git commit -q -m "docs: add repository phrase list"

printf '\nbanned: %s soon\n' "coming" \
  >> .agent-guidelines/rules/no-plans-on-main.md
git add .agent-guidelines/rules/no-plans-on-main.md
git commit -q -m "docs: update installed phrase list"

mkdir -p nested
printf 'banned: %s soon\n' "coming" > nested/no-plans-on-main.md
git add nested/no-plans-on-main.md
expect_fail git commit -m "docs: add unrelated phrase list"
git reset -q -- nested/no-plans-on-main.md
rm -rf nested

# Banned-phrase guard (commit message): forward-looking message text
# fails; a clean message for the same staged content passes.
printf 'h\n' > file-h.txt
git add file-h.txt
bad_msg_phrase="coming"" soon"
expect_fail git commit -m "docs: support ${bad_msg_phrase}"
git commit -q -m "docs: add file h"

# Merge exemption: a --no-ff merge into main passes both the
# main-branch guard and the conventional guard.
git checkout -q main
git merge -q --no-ff -m "Merge branch 'feat/hook-check'" feat/hook-check

# Banned-phrase guard (merge body): commit-msg runs for merges, so a
# forward-looking merge body fails; a clean body then passes.
git checkout -q -b feat/merge-body-check
printf 'i\n' > file-i.txt
git add file-i.txt
git commit -q -m "feat: add file i"
git checkout -q main
expect_fail git merge --no-ff \
  -m "Merge branch 'feat/merge-body-check'" \
  -m "More work ${bad_msg_phrase}." feat/merge-body-check
git merge --abort 2>/dev/null || true
git merge -q --no-ff -m "Merge branch 'feat/merge-body-check'" \
  feat/merge-body-check

# Branch-name guard: pushes are validated against the pushed refs.
git init -q --bare "$REMOTE"
git remote add origin "$REMOTE"

git push -q origin main

git branch badname
expect_fail git push origin badname

# Every documented Conventional Commit type prefix is accepted.
head_sha="$(git rev-parse HEAD)"
zero_sha="$(printf '0%.0s' {1..40})"
for prefix in feat fix refactor perf docs style test build ci chore revert; do
  branch_name="${prefix}/policy-check"
  printf 'refs/heads/%s %s refs/heads/%s %s\n' \
    "$branch_name" "$head_sha" "$branch_name" "$zero_sha" |
    .git/hooks/pre-push
done

# Broad review language is valid in a branch name.
phrase_branch="feat/handle-fol""lowup"
git branch "$phrase_branch"
git push -q origin "$phrase_branch"
git push -q origin ":$phrase_branch"
git branch -q -d "$phrase_branch"

# An explicit promise is rejected; the name is assembled from fragments.
planned_branch="feat/com""ing-soon"
git branch "$planned_branch"
expect_fail git push origin "$planned_branch"
git branch -q -d "$planned_branch"

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
