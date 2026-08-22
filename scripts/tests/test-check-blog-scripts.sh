#!/usr/bin/env bash
#
# Self-contained tests for the blog-specific pre-commit hooks
# (check-blog-not-howto.sh, check-blog-fold.sh) and the blog-post branch
# of check-description.sh. No test framework dependency -- plain bash
# assertions against fixture files written to a scratch temp dir, matching
# this repo's existing scripts/ style (no bats/shellspec anywhere else in
# the repo).
#
# Run: bash scripts/tests/test-check-blog-scripts.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR" || exit 1

PASS=0
FAIL=0

# assert_exit EXPECTED_EXIT DESCRIPTION -- CMD...
assert_exit() {
    local expected="$1"
    local desc="$2"
    shift 2
    local actual
    "$@" >/dev/null 2>&1
    actual=$?
    if [[ "$actual" -eq "$expected" ]]; then
        echo "  ok - $desc"
        PASS=$((PASS + 1))
    else
        echo "  NOT OK - $desc (expected exit $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

write_post() {
    local path="$1"
    shift
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$@" > "$path"
}

blog_dir="docs/blog/posts"

echo "check-blog-not-howto.sh"

# A narrative post with no code blocks at all must pass.
write_post "$blog_dir/2026-01-01-narrative-only.md" \
    '---' 'title: Narrative Only' '---' '' \
    'I remember the night everything broke. There was no code here, just the story.' \
    '' '<!-- more -->' '' 'The rest of the story continues, still no code.'
assert_exit 0 "pure narrative post (no code blocks) passes" \
    "$SCRIPT_DIR/check-blog-not-howto.sh" "$blog_dir/2026-01-01-narrative-only.md"

# A single short illustrative snippet (below both thresholds) must pass.
write_post "$blog_dir/2026-01-02-one-short-snippet.md" \
    '---' 'title: One Short Snippet' '---' '' \
    'I remember running one command that changed everything.' \
    '' '<!-- more -->' '' \
    '```bash' 'git commit --no-verify' '```' '' \
    'That one line summed up the whole incident.'
assert_exit 0 "single short code block under threshold passes" \
    "$SCRIPT_DIR/check-blog-not-howto.sh" "$blog_dir/2026-01-02-one-short-snippet.md"

# Mermaid diagrams, however large, must never trip the how-to check.
write_post "$blog_dir/2026-01-03-mermaid-only.md" \
    '---' 'title: Mermaid Only' '---' '' \
    'I remember drawing this on a whiteboard first.' '' '<!-- more -->' '' \
    '```mermaid' 'flowchart LR' '  A --> B' '  B --> C' '  C --> D' '  D --> E' '```'
assert_exit 0 "mermaid-only diagram passes regardless of size" \
    "$SCRIPT_DIR/check-blog-not-howto.sh" "$blog_dir/2026-01-03-mermaid-only.md"

# Three or more real code blocks must fail even if each is short.
write_post "$blog_dir/2026-01-04-three-blocks.md" \
    '---' 'title: Three Blocks' '---' '' 'Setup went like this.' '' '<!-- more -->' '' \
    '```bash' 'step one' '```' '```bash' 'step two' '```' '```bash' 'step three' '```'
assert_exit 1 "3+ non-mermaid code blocks fails even when short" \
    "$SCRIPT_DIR/check-blog-not-howto.sh" "$blog_dir/2026-01-04-three-blocks.md"

# A single code block over the line threshold must fail.
long_block=()
for i in $(seq 1 15); do long_block+=("line $i"); done
write_post "$blog_dir/2026-01-05-long-block.md" \
    '---' 'title: Long Block' '---' '' 'It was a big migration.' '' '<!-- more -->' '' \
    '```yaml' "${long_block[@]}" '```'
assert_exit 1 "single code block over the line threshold fails" \
    "$SCRIPT_DIR/check-blog-not-howto.sh" "$blog_dir/2026-01-05-long-block.md"

# The real content-machine PR #274 case that motivated this hook: verbatim
# regression fixture, trimmed to its code-relevant shape.
write_post "$blog_dir/2026-08-09-real-howto-regression.md" \
    '---' 'title: My Journey to Declarative App Delivery on Kubernetes' '---' '' \
    'I remember the cold sweat, staring at a failing deployment log.' '' '<!-- more -->' '' \
    '```bash' 'kubectl apply -f app.yaml' 'kubectl rollout status deploy/app' 'kubectl get pods -w' '```' \
    '```yaml' 'apiVersion: v1' 'kind: Application' 'metadata:' '  name: app' 'spec:' '  source: git' '```' \
    '```bash' 'argocd app sync app' 'argocd app wait app' '```'
assert_exit 1 "regression: a real merged how-to-shaped blog post fails" \
    "$SCRIPT_DIR/check-blog-not-howto.sh" "$blog_dir/2026-08-09-real-howto-regression.md"

# Non-blog docs must never be touched by this hook.
write_post "docs/build/some-guide/index.md" \
    '---' 'title: A Guide' '---' '' \
    '```bash' 'step one' '```' '```bash' 'step two' '```' '```bash' 'step three' '```'
assert_exit 0 "articles/guides outside docs/blog/posts/ are ignored" \
    "$SCRIPT_DIR/check-blog-not-howto.sh" "docs/build/some-guide/index.md"

echo ""
echo "check-blog-fold.sh"

# Missing <!-- more --> entirely must fail.
write_post "$blog_dir/2026-02-01-no-more-marker.md" \
    '---' 'title: No More Marker' '---' '' 'This post never excerpts.'
assert_exit 1 "missing <!-- more --> marker fails" \
    "$SCRIPT_DIR/check-blog-fold.sh" "$blog_dir/2026-02-01-no-more-marker.md"

# An admonition before the fold must fail.
write_post "$blog_dir/2026-02-02-admonition-above-fold.md" \
    '---' 'title: Admonition Above Fold' '---' '' \
    '!!! note "Heads up"' '    This appears before the excerpt cuts off.' '' \
    '<!-- more -->' '' 'The rest of the story.'
assert_exit 1 "admonition before <!-- more --> fails" \
    "$SCRIPT_DIR/check-blog-fold.sh" "$blog_dir/2026-02-02-admonition-above-fold.md"

# An admonition after the fold is fine.
write_post "$blog_dir/2026-02-03-admonition-below-fold.md" \
    '---' 'title: Admonition Below Fold' '---' '' \
    'A clean narrative opening with no callouts.' '' '<!-- more -->' '' \
    '!!! tip "Worth remembering"' '    This is fine, it is after the excerpt.'
assert_exit 0 "admonition after <!-- more --> passes" \
    "$SCRIPT_DIR/check-blog-fold.sh" "$blog_dir/2026-02-03-admonition-below-fold.md"

# A clean post with the marker and no admonition at all passes.
write_post "$blog_dir/2026-02-04-clean.md" \
    '---' 'title: Clean' '---' '' 'A clean narrative opening.' '' '<!-- more -->' '' 'And it continues cleanly.'
assert_exit 0 "post with marker and no admonition passes" \
    "$SCRIPT_DIR/check-blog-fold.sh" "$blog_dir/2026-02-04-clean.md"

echo ""
echo "check-description.sh (blog-post branch)"

# Description over the 160-char blog cap must fail, even though it would
# pass the general 200-char docs cap -- this is the real bug behind
# content-machine PRs #274 and #275 (250-char descriptions merged clean).
long_desc="This description is deliberately written to run past one hundred and sixty characters so that it exercises the stricter blog-specific cap instead of the general two-hundred-character docs limit that used to apply here by mistake."
write_post "$blog_dir/2026-03-01-long-description.md" \
    '---' 'title: Long Description' 'description: >-' "  $long_desc" '---' '' \
    'Body text.' '' '<!-- more -->' '' 'More body text.'
assert_exit 1 "blog description over 160 chars fails (was previously exempt)" \
    "$SCRIPT_DIR/check-description.sh" "$blog_dir/2026-03-01-long-description.md"

# A description within the blog's 100-160 range passes.
ok_desc="This description sits comfortably inside the required range for a blog post, long enough to be useful and short enough to fit under the cap."
write_post "$blog_dir/2026-03-02-ok-description.md" \
    '---' 'title: OK Description' 'description: >-' "  $ok_desc" '---' '' \
    'Body text.' '' '<!-- more -->' '' 'More body text.'
assert_exit 0 "blog description within 100-160 chars passes" \
    "$SCRIPT_DIR/check-description.sh" "$blog_dir/2026-03-02-ok-description.md"

# A blog post missing description entirely now fails too (used to be a
# blanket exemption).
write_post "$blog_dir/2026-03-03-missing-description.md" \
    '---' 'title: Missing Description' '---' '' \
    'Body text.' '' '<!-- more -->' '' 'More body text.'
assert_exit 1 "blog post with no description fails" \
    "$SCRIPT_DIR/check-description.sh" "$blog_dir/2026-03-03-missing-description.md"

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
