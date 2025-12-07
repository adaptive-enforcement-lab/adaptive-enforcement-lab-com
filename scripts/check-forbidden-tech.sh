#!/usr/bin/env bash
#
# Pre-commit hook to enforce vendor-neutral technology choices
# Based on content policies in README.md

set -euo pipefail

EXIT_CODE=0
VIOLATIONS=()

# Exceptions: paths where historical reference is acceptable
EXCEPTION_PATHS=(
    "docs/migration-guides/"
    "docs/developer-guide/"  # Technical documentation may reference common tools
    "scripts/check-forbidden-tech.sh"  # This script itself contains the patterns
    "CHANGELOG.md"
    "docs/blog/posts/.*forbidden.*"  # Blog posts about the pattern itself
    "docs/blog/posts/2025-12-04-pre-commit-security-gates.md"  # Examples of violations
)

# Forbidden patterns by category
# docker CLI is OK for runtime commands (ps, logs, exec)
# docker for images is NOT OK - use OCI tools (buildah, podman)
declare -A FORBIDDEN_PATTERNS=(
    ["Docker Hub/Registry"]="docker\.io/|Docker\s+Hub|dockerhub\.com|hub\.docker\.com"
    ["Docker image ops"]="docker\s+(build|push|pull|tag|commit|save|load)"
    ["Terraform"]="terraform\s+(init|plan|apply|destroy)|\.tf\s|terraform\s*\{"
    ["AWS-specific"]="\.amazonaws\.com|aws_[a-z_]+\s*=|AWS::[A-Z]"
)

declare -A PREFERRED_ALTERNATIVES=(
    ["Docker Hub/Registry"]="GCR, Artifact Registry, OCI-compatible registries"
    ["Docker image ops"]="buildah, podman (OCI-compliant tools)"
    ["Terraform"]="Crossplane, CNRM, Pulumi"
    ["AWS-specific"]="GCP or cloud-agnostic patterns"
)

is_exception() {
    local file="$1"
    for exception in "${EXCEPTION_PATHS[@]}"; do
        if [[ "$file" =~ $exception ]]; then
            return 0
        fi
    done
    return 1
}

check_file() {
    local file="$1"

    if is_exception "$file"; then
        return 0
    fi

    for tech in "${!FORBIDDEN_PATTERNS[@]}"; do
        local pattern="${FORBIDDEN_PATTERNS[$tech]}"
        local matches

        # Use grep -n to get line numbers, -i for case insensitive, -E for extended regex
        if matches=$(grep -niE "$pattern" "$file" 2>/dev/null); then
            while IFS=: read -r line_num match; do
                VIOLATIONS+=("$file:$line_num - $tech: $(echo "$match" | sed 's/^[[:space:]]*//')")
                EXIT_CODE=1
            done <<< "$matches"
        fi
    done
}

# Check all provided files
for file in "$@"; do
    if [[ -f "$file" ]]; then
        check_file "$file"
    fi
done

# Report violations
if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
    echo ""
    echo "========================================" >&2
    echo "FORBIDDEN TECHNOLOGY DETECTED" >&2
    echo "========================================" >&2
    echo "" >&2

    for violation in "${VIOLATIONS[@]}"; do
        echo "  $violation" >&2
    done

    echo "" >&2
    echo "Content Policies (README.md):" >&2
    echo "" >&2

    for tech in "${!FORBIDDEN_PATTERNS[@]}"; do
        echo "  ❌ $tech" >&2
        echo "  ✅ Prefer: ${PREFERRED_ALTERNATIVES[$tech]}" >&2
        echo "" >&2
    done

    echo "If this is historical reference or migration guide," >&2
    echo "add the path to EXCEPTION_PATHS in this script." >&2
    echo "" >&2
fi

exit $EXIT_CODE
