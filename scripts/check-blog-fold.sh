#!/usr/bin/env bash
#
# Pre-commit hook enforcing two structural rules for blog posts from
# content-review.md:
#
#   1. A `<!-- more -->` marker must be present -- it's what mkdocs-material's
#      blog plugin uses to build the excerpt shown on the blog index and in
#      the RSS feed.
#   2. No admonition (`!!! note`, `!!! tip`, `!!! warning`, ...) may appear
#      before that marker -- "no admonitions above the fold". The excerpt
#      shown on the index page should read as plain narrative, not open on a
#      callout box.
#
# Confirmed live against this repo: 2026-08-09-gitops-application-delivery-
# patterns-across-a-kubernetes-fleet.md opens on a `!!! note` block before
# its `<!-- more -->` marker and merged anyway -- nothing caught it.

set -euo pipefail

EXIT_CODE=0

check_file() {
    local file="$1"

    if [[ "$file" != docs/blog/posts/*.md ]]; then
        return 0
    fi

    if ! grep -qF '<!-- more -->' "$file"; then
        echo "" >&2
        echo "  ❌ $file: missing required '<!-- more -->' excerpt marker" >&2
        EXIT_CODE=1
        return
    fi

    # Everything before the first `<!-- more -->` line, i.e. what the blog
    # index / RSS feed shows as the excerpt.
    local before_fold
    before_fold=$(awk '/<!-- more -->/{exit} {print}' "$file")

    if echo "$before_fold" | grep -qE '^!!![[:space:]]'; then
        echo "" >&2
        echo "  ❌ $file: admonition appears above the '<!-- more -->' fold" >&2
        echo "     Move any !!! note/tip/warning block to after the marker." >&2
        EXIT_CODE=1
    fi
}

for file in "$@"; do
    if [[ -f "$file" ]] && [[ "$file" == *.md ]]; then
        check_file "$file"
    fi
done

exit $EXIT_CODE
