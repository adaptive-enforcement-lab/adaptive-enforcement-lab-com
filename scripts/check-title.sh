#!/usr/bin/env bash
#
# Pre-commit hook to enforce title frontmatter for navigation and SEO
# Checks that documentation pages have titles with optimal length

set -euo pipefail

EXIT_CODE=0
MISSING=()
TOO_SHORT=()
TOO_LONG=()

# Files to exclude from title requirement
EXCEPTION_PATTERNS=(
    "^CHANGELOG\.md$"              # No title needed
    "^README\.md$"                 # No title needed
    "^\.content-machine/"          # Internal planning docs
    "^docs/tags\.md$"              # Special generated page
    "^docs/includes/"              # Include files
    "/\.meta\.yml$"                # Directory-wide metadata files
)

# Optimal length for page titles
MIN_LENGTH=5
OPTIMAL_MIN=10
OPTIMAL_MAX=60
MAX_ALLOWED=80

is_exception() {
    local file="$1"
    for pattern in "${EXCEPTION_PATTERNS[@]}"; do
        if [[ "$file" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

extract_title() {
    local file="$1"
    local in_frontmatter=0
    local title=""

    while IFS= read -r line; do
        # Start of frontmatter
        if [[ "$line" == "---" ]] && [[ $in_frontmatter -eq 0 ]]; then
            in_frontmatter=1
            continue
        fi

        # End of frontmatter
        if [[ "$line" == "---" ]] && [[ $in_frontmatter -eq 1 ]]; then
            break
        fi

        # Inside frontmatter
        if [[ $in_frontmatter -eq 1 ]]; then
            # Extract title field
            if [[ "$line" =~ ^title:[[:space:]]*(.*) ]]; then
                title="${BASH_REMATCH[1]}"
                # Remove quotes if present
                title="${title#\"}"
                title="${title%\"}"
                title="${title#\'}"
                title="${title%\'}"
                break
            fi
        fi
    done < "$file"

    echo "$title"
}

check_file() {
    local file="$1"

    # Only check files in docs/ directory
    if [[ "$file" != docs/* ]]; then
        return 0
    fi

    if is_exception "$file"; then
        return 0
    fi

    local title
    title=$(extract_title "$file")

    # Check if title exists
    if [[ -z "$title" ]]; then
        MISSING+=("$file")
        EXIT_CODE=1
        return
    fi

    # Check length
    local length=${#title}

    if (( length < MIN_LENGTH )); then
        TOO_SHORT+=("$file|$length|$title")
        EXIT_CODE=1
    elif (( length > MAX_ALLOWED )); then
        TOO_LONG+=("$file|$length|$title")
        EXIT_CODE=1
    fi
}

# Check all provided files
for file in "$@"; do
    if [[ -f "$file" ]] && [[ "$file" == *.md ]]; then
        check_file "$file"
    fi
done

# Report violations
if [[ ${#MISSING[@]} -gt 0 ]] || [[ ${#TOO_SHORT[@]} -gt 0 ]] || [[ ${#TOO_LONG[@]} -gt 0 ]]; then
    echo ""
    echo "========================================" >&2
    echo "TITLE FRONTMATTER ISSUES" >&2
    echo "========================================" >&2
    echo "" >&2

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        echo "Missing title frontmatter:" >&2
        for file in "${MISSING[@]}"; do
            echo "  ❌ $file" >&2
        done
        echo "" >&2
    fi

    if [[ ${#TOO_SHORT[@]} -gt 0 ]]; then
        echo "Title too short (< $MIN_LENGTH chars):" >&2
        for entry in "${TOO_SHORT[@]}"; do
            IFS='|' read -r file length title <<< "$entry"
            echo "  ❌ $file" >&2
            echo "     Length: $length chars" >&2
            echo "     Current: $title" >&2
        done
        echo "" >&2
    fi

    if [[ ${#TOO_LONG[@]} -gt 0 ]]; then
        echo "Title too long (> $MAX_ALLOWED chars):" >&2
        for entry in "${TOO_LONG[@]}"; do
            IFS='|' read -r file length title <<< "$entry"
            echo "  ⚠️  $file" >&2
            echo "     Length: $length chars" >&2
            echo "     Current: $title" >&2
        done
        echo "" >&2
    fi

    echo "Best Practices:" >&2
    echo "" >&2
    echo "  📏 Optimal length: $OPTIMAL_MIN-$OPTIMAL_MAX chars" >&2
    echo "  📱 Appears in navigation, browser tabs, and page headers" >&2
    echo "  🔍 Used by search engines in results" >&2
    echo "" >&2
    echo "Composition tips:" >&2
    echo "  ✅ Clear and descriptive" >&2
    echo "  ✅ Unique within the site" >&2
    echo "  ✅ Use sentence case or title case consistently" >&2
    echo "  ❌ Don't use generic titles like 'Introduction'" >&2
    echo "  ❌ Don't include site name (added automatically)" >&2
    echo "" >&2
    echo "Example frontmatter:" >&2
    echo "" >&2
    echo "  ---" >&2
    echo "  title: GitHub Core App Setup" >&2
    echo "  description: >-" >&2
    echo "    Configure organization-level GitHub Apps for secure automation." >&2
    echo "  ---" >&2
    echo "" >&2
fi

exit $EXIT_CODE
