#!/usr/bin/env bash
#
# Pre-commit hook enforcing the blog-vs-article content type distinction
# (content-review.md's "most critical check"): blog posts are emotional
# narratives, not how-tos. A blog post that carries substantial fenced
# code blocks (setup commands, YAML manifests, Go snippets, etc.) is
# almost always misfiled -- that content belongs in an article/guide
# under docs/build/, docs/enforce/, docs/patterns/, etc., with the blog
# post linking to it instead.
#
# Mermaid diagrams are exempt: a flowchart is a narrative illustration,
# not a workflow the reader is meant to type in and run.
#
# Thresholds (3+ non-mermaid code blocks, or >10 total non-mermaid code
# lines) were picked against this repo's own real published posts: of 37
# posts with at least one non-mermaid code block, this flags 35 of them
# -- including a post with 9 blocks / 203 lines of bash+yaml+go (a
# complete GitHub Action tutorial merged as a blog post) -- while leaving
# genuinely narrative posts with a single short illustrative line alone.

set -euo pipefail

EXIT_CODE=0

MAX_BLOCKS_ALLOWED=2
MAX_LINES=10

check_file() {
    local file="$1"

    if [[ "$file" != docs/blog/posts/*.md ]]; then
        return 0
    fi

    # Extract fenced code blocks (```lang ... ```), track the language of
    # each and count body lines, skipping mermaid blocks entirely.
    local in_block=0
    local lang=""
    local block_lines=0
    local total_blocks=0
    local total_lines=0

    while IFS= read -r line; do
        if [[ $in_block -eq 0 ]]; then
            if [[ "$line" =~ ^\`\`\`[[:space:]]*([a-zA-Z0-9_-]*) ]]; then
                lang="${BASH_REMATCH[1]}"
                in_block=1
                block_lines=0
            fi
        else
            if [[ "$line" =~ ^\`\`\` ]]; then
                in_block=0
                if [[ "${lang,,}" != "mermaid" ]]; then
                    total_blocks=$((total_blocks + 1))
                    total_lines=$((total_lines + block_lines))
                fi
            else
                block_lines=$((block_lines + 1))
            fi
        fi
    done < "$file"

    if [[ $total_blocks -gt $MAX_BLOCKS_ALLOWED ]] || [[ $total_lines -gt $MAX_LINES ]]; then
        echo "" >&2
        echo "========================================" >&2
        echo "BLOG POST LOOKS LIKE A HOW-TO" >&2
        echo "========================================" >&2
        echo "" >&2
        echo "  ❌ $file" >&2
        echo "     $total_blocks non-mermaid code block(s), $total_lines total lines" >&2
        echo "" >&2
        echo "Blog posts tell an emotional/narrative journey and must NOT contain" >&2
        echo "workflows, code blocks, or step-by-step instructions -- that content" >&2
        echo "belongs in an article/guide (docs/build/, docs/enforce/, docs/patterns/," >&2
        echo "docs/secure/, ...), with this post linking to it under a '## Related'" >&2
        echo "section instead. See content-review.md's 'CRITICAL CHECK'." >&2
        echo "" >&2
        echo "  Mermaid diagrams are fine -- they're illustrations, not workflows." >&2
        echo "" >&2
        EXIT_CODE=1
    fi
}

for file in "$@"; do
    if [[ -f "$file" ]] && [[ "$file" == *.md ]]; then
        check_file "$file"
    fi
done

exit $EXIT_CODE
