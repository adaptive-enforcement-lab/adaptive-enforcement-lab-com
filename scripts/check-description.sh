#!/usr/bin/env bash
#
# Pre-commit hook to enforce description frontmatter for SEO and social cards
# Checks that documentation pages have descriptions with optimal length

set -euo pipefail

EXIT_CODE=0
MISSING=()
TOO_SHORT=()
TOO_LONG=()
OPTIMAL=()

# Files to exclude from description requirement
EXCEPTION_PATTERNS=(
    "^docs/blog/posts/"           # Blog posts use different frontmatter
    "^CHANGELOG\.md$"              # No description needed
    "^README\.md$"                 # No description needed
    "^\.content-machine/"          # Internal planning docs
    "^docs/tags\.md$"              # Special generated page
    "^docs/index\.md$"             # Homepage uses site_description
    "/\.meta\.yml$"                # Directory-wide metadata files
)

# Optimal length: 155-160 chars for search results and social cards
MIN_RECOMMENDED=100
OPTIMAL_MIN=155
OPTIMAL_MAX=160
MAX_ALLOWED=200

is_exception() {
    local file="$1"
    for pattern in "${EXCEPTION_PATTERNS[@]}"; do
        if [[ "$file" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

extract_description() {
    local file="$1"
    local in_frontmatter=0
    local description=""
    local collecting=0

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
            # Start of description field
            if [[ "$line" =~ ^description:[[:space:]]*(.*) ]]; then
                description="${BASH_REMATCH[1]}"
                # Check if it's a folded scalar (>- or >)
                if [[ "$description" =~ ^[\>\|][-]?[[:space:]]*$ ]]; then
                    collecting=1
                    description=""
                fi
            # Collecting multiline description
            elif [[ $collecting -eq 1 ]]; then
                # Stop if we hit another top-level key
                if [[ "$line" =~ ^[a-zA-Z_-]+: ]]; then
                    break
                fi
                # Remove leading spaces and add to description
                trimmed="${line#"${line%%[![:space:]]*}"}"
                if [[ -n "$trimmed" ]]; then
                    description="${description}${description:+ }${trimmed}"
                fi
            fi
        fi
    done < "$file"

    echo "$description"
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

    local description
    description=$(extract_description "$file")

    # Check if description exists
    if [[ -z "$description" ]]; then
        MISSING+=("$file")
        EXIT_CODE=1
        return
    fi

    # Check length
    local length=${#description}

    if (( length < MIN_RECOMMENDED )); then
        TOO_SHORT+=("$file|$length|$description")
        EXIT_CODE=1
    elif (( length > MAX_ALLOWED )); then
        TOO_LONG+=("$file|$length|$description")
        EXIT_CODE=1
    elif (( length < OPTIMAL_MIN )) || (( length > OPTIMAL_MAX )); then
        # Within acceptable range but not optimal
        OPTIMAL+=("$file|$length|$description")
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
    echo "DESCRIPTION FRONTMATTER ISSUES" >&2
    echo "========================================" >&2
    echo "" >&2

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        echo "Missing description frontmatter:" >&2
        for file in "${MISSING[@]}"; do
            echo "  ❌ $file" >&2
        done
        echo "" >&2
    fi

    if [[ ${#TOO_SHORT[@]} -gt 0 ]]; then
        echo "Description too short (< $MIN_RECOMMENDED chars):" >&2
        for entry in "${TOO_SHORT[@]}"; do
            IFS='|' read -r file length desc <<< "$entry"
            echo "  ❌ $file" >&2
            echo "     Length: $length chars" >&2
            echo "     Current: ${desc:0:80}..." >&2
        done
        echo "" >&2
    fi

    if [[ ${#TOO_LONG[@]} -gt 0 ]]; then
        echo "Description too long (> $MAX_ALLOWED chars):" >&2
        for entry in "${TOO_LONG[@]}"; do
            IFS='|' read -r file length desc <<< "$entry"
            echo "  ⚠️  $file" >&2
            echo "     Length: $length chars" >&2
            echo "     Current: ${desc:0:80}..." >&2
        done
        echo "" >&2
    fi

    echo "Best Practices:" >&2
    echo "" >&2
    echo "  📏 Optimal length: $OPTIMAL_MIN-$OPTIMAL_MAX chars" >&2
    echo "  📱 Appears in search results, social cards, and meta tags" >&2
    echo "" >&2
    echo "Composition tips:" >&2
    echo "  ✅ Start with action verbs or benefits" >&2
    echo "  ✅ Answer: what does this page help you do?" >&2
    echo "  ✅ Include 1-2 key terms for SEO" >&2
    echo "  ❌ Don't repeat the page title verbatim" >&2
    echo "  ❌ Don't start with 'This page...'" >&2
    echo "" >&2
    echo "Example frontmatter:" >&2
    echo "" >&2
    echo "  ---" >&2
    echo "  description: >-" >&2
    echo "    Find vulnerabilities early with automated security scanning." >&2
    echo "    SBOM generation, supply chain compliance, and GitHub Actions" >&2
    echo "    integration for DevSecOps workflows." >&2
    echo "  tags:" >&2
    echo "    - security" >&2
    echo "    - automation" >&2
    echo "  ---" >&2
    echo "" >&2
fi

# Report optimal warnings (don't fail, just inform)
if [[ ${#OPTIMAL[@]} -gt 0 ]]; then
    echo "Acceptable but not optimal length ($OPTIMAL_MIN-$OPTIMAL_MAX recommended):" >&2
    for entry in "${OPTIMAL[@]}"; do
        IFS='|' read -r file length desc <<< "$entry"
        echo "  ℹ️  $file ($length chars)" >&2
    done
    echo "" >&2
fi

exit $EXIT_CODE
