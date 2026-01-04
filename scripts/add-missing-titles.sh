#!/usr/bin/env bash
#
# Add missing title frontmatter to documentation files
# Extracts title from first H1 heading or generates from file path

set -euo pipefail

add_title_to_file() {
    local file="$1"
    local title=""

    # Try to extract H1 heading (first line starting with #)
    while IFS= read -r line; do
        if [[ "$line" =~ ^#[[:space:]]+(.*) ]]; then
            title="${BASH_REMATCH[1]}"
            break
        fi
    done < "$file"

    # If no H1 found, generate from file path
    if [[ -z "$title" ]]; then
        # Get filename without extension
        local basename=$(basename "$file" .md)
        # Convert kebab-case and snake_case to Title Case
        title=$(echo "$basename" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) tolower(substr($i,2))}}1')
    fi

    # Check if file has frontmatter
    local has_frontmatter=false
    local first_line=$(head -n1 "$file")
    if [[ "$first_line" == "---" ]]; then
        has_frontmatter=true
    fi

    if $has_frontmatter; then
        # Insert title as second line (after first ---)
        # Read the file, find the first ---, add title after it
        awk -v title="$title" '
        NR==1 && /^---$/ { print; print "title: " title; next }
        { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        # No frontmatter, add it at the beginning
        {
            echo "---"
            echo "title: $title"
            echo "---"
            cat "$file"
        } > "$file.tmp" && mv "$file.tmp" "$file"
    fi

    echo "✅ Added title to $file: $title"
}

# Get all files missing titles from check-title.sh
missing_files=$(find docs -name "*.md" -type f | xargs ./scripts/check-title.sh 2>&1 | grep "❌" | awk '{print $2}')

for file in $missing_files; do
    if [[ -f "$file" ]]; then
        add_title_to_file "$file"
    fi
done

echo ""
echo "Title addition complete!"
