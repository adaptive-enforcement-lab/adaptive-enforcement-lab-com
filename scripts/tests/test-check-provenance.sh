#!/usr/bin/env bash
#
# Tests for check-provenance.sh against a scratch git repository, so the
# first-commit rule runs on real history. No network.
#
# Run: bash scripts/tests/test-check-provenance.sh

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/check-provenance.sh"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR" || exit 1

PASS=0
FAIL=0

assert_exit() {
    local expected="$1" desc="$2"
    shift 2
    "$@" >/dev/null 2>&1
    local actual=$?
    if [[ "$actual" -eq "$expected" ]]; then
        echo "  ok - $desc"
        PASS=$((PASS + 1))
    else
        echo "  NOT OK - $desc (expected exit $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

write_page() {
    local path="$1"
    shift
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$@" > "$path"
}

commit_as() {
    local name="$1" msg="$2"
    git add -A
    git -c user.name="$name" -c user.email="$name@example.invalid" commit -q -m "$msg"
}

# Hermetic git: the fixture repo must not inherit the caller's config.
export GIT_CONFIG_GLOBAL="$TMP_DIR/.gitconfig" GIT_CONFIG_NOSYSTEM=1
: > "$GIT_CONFIG_GLOBAL"
git init -q .

post="docs/blog/posts/2026-01-01-post.md"
guide="docs/build/guide/index.md"

echo "check-provenance.sh"

write_page "$guide" '---' 'title: Guide' '---' '' 'Body.'
assert_exit 1 "page without provenance fails" "$SCRIPT" "$guide"

write_page "$guide" '---' 'title: Guide' 'provenance: robot' '---' '' 'Body.'
assert_exit 1 "unknown provenance value fails" "$SCRIPT" "$guide"

write_page "$guide" '---' 'title: Guide' 'provenance: human' '---' '' '```yaml' 'provenance: machine' '```'
assert_exit 0 "human guide passes; body code is not frontmatter" "$SCRIPT" "$guide"

write_page "docs/includes/snippet.md" '*[CI]: Continuous Integration'
assert_exit 0 "docs/includes is exempt" "$SCRIPT" "docs/includes/snippet.md"

write_page "$post" '---' 'title: Post' 'provenance: machine' 'authors:' '  - mark' '---'
assert_exit 1 "machine post listing mark fails" "$SCRIPT" "$post"

write_page "$post" '---' 'title: Post' 'provenance: machine' 'authors:' '  - content-machine' '---'
assert_exit 0 "machine post listing content-machine passes" "$SCRIPT" "$post"

write_page "$post" '---' 'title: Post' 'provenance: human_edited' 'authors: [content-machine, mark]' '---'
assert_exit 0 "human_edited post with inline authors passes" "$SCRIPT" "$post"

write_page "$post" '---' 'title: Post' 'provenance: human_edited' 'authors:' '  - mark' '---'
assert_exit 1 "human_edited post without content-machine fails" "$SCRIPT" "$post"

# First-commit rule: the bot creates the post, a human renames it.
write_page "$post" '---' 'title: Post' 'provenance: machine' 'authors:' '  - content-machine' '---' '' 'Body text that survives the rename.'
commit_as "ael-content-machine[bot]" "draft"
renamed="docs/blog/posts/2026-01-01-renamed.md"
git mv "$post" "$renamed"
commit_as "Human Editor" "rename"

write_page "$renamed" '---' 'title: Post' 'provenance: human' 'authors:' '  - mark' '---' '' 'Body text that survives the rename.'
assert_exit 1 "bot-first file claiming human fails across a rename" "$SCRIPT" "$renamed"

write_page "$renamed" '---' 'title: Post' 'provenance: human_edited' 'authors:' '  - mark' '  - content-machine' '---' '' 'Body text that survives the rename.'
assert_exit 0 "bot-first file claiming human_edited passes" "$SCRIPT" "$renamed"

human_guide="docs/build/human/index.md"
write_page "$human_guide" '---' 'title: Guide' 'provenance: human' '---' '' 'Body.'
commit_as "Human Editor" "guide"
assert_exit 0 "human-first file claiming human passes" "$SCRIPT" "$human_guide"

# A new human page that resembles a bot page is not traced to it as a copy.
copy="docs/build/copy/index.md"
mkdir -p "$(dirname "$copy")"
cp "$renamed" "$copy"
commit_as "Human Editor" "similar page"
write_page "$copy" '---' 'title: Post' 'provenance: human' '---' '' 'Body text that survives the rename.'
assert_exit 0 "human page similar to a bot page is not a copy of it" "$SCRIPT" "$copy"

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
