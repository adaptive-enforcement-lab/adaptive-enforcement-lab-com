#!/usr/bin/env bash
# Check markdown files for excessive length
# Files over 350 lines should be split along logical L2 header groupings

set -euo pipefail

MAX_LINES=350
EXIT_CODE=0

for file in "$@"; do
    if [[ -f "$file" ]]; then
        line_count=$(wc -l < "$file" | tr -d ' ')
        if [[ $line_count -gt $MAX_LINES ]]; then
            echo "ERROR: $file has $line_count lines (max: $MAX_LINES)"
            echo "       Content needs to be split along logical L2 header (##) groupings for human consumability."
            echo ""
            # Show L2 headers to help identify split points
            echo "       Current L2 headers in $file:"
            grep -n "^## " "$file" | sed 's/^/         /' || echo "         (no L2 headers found)"
            echo ""
            EXIT_CODE=1
        fi
    fi
done

exit $EXIT_CODE
