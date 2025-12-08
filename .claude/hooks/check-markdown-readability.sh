#!/bin/bash
set -euo pipefail

# Post-write hook to run readability checks on newly created markdown files
# This hook runs after the Write or Edit tool is used

# Read the JSON input from stdin containing tool information
input=$(cat)

# Extract the file path from the JSON
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only process markdown files
if [[ ! "$file_path" =~ \.md$ ]]; then
  exit 0
fi

# Check if file exists
if [[ ! -f "$file_path" ]]; then
  exit 0
fi

# Get the project directory
project_dir="${CLAUDE_PROJECT_DIR:-.}"

# Change to project directory to ensure pre-commit works correctly
cd "$project_dir"

# Run readability-docs via pre-commit on the specific file
# Capture output to show it in stdout so Claude can see it
output=$(pre-commit run readability-docs --files "$file_path" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo "✓ Readability check passed for $file_path"
  exit 0
else
  # Output to stdout so it appears in tool results
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  READABILITY ISSUES DETECTED IN $file_path"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "These issues will BLOCK git commits. Fix them now!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "$output"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  # Exit 0 so it doesn't block, but the output warns Claude
  exit 0
fi
