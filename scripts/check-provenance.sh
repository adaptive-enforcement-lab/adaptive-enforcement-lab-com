#!/usr/bin/env bash
#
# Enforce the provenance split between human and machine-drafted pages.
#
#   1. Every page under docs/ (except docs/includes/) carries a frontmatter
#      `provenance:` key: human, human_edited or machine.
#   2. A file whose first commit (following renames, not copies) is by the content-machine
#      bot identity may not claim `human`.
#   3. Blog posts list the authors their provenance implies:
#      human -> mark; human_edited -> mark, content-machine;
#      machine -> content-machine.
#
# Rule 2 reads git history, so CI needs a full clone (fetch-depth: 0).

set -euo pipefail

BOT_AUTHOR="${PROVENANCE_BOT_AUTHOR:-ael-content-machine[bot]}"
HUMAN_AUTHOR="mark"
MACHINE_AUTHOR="content-machine"

EXIT_CODE=0
IN_GIT=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IN_GIT=1
    if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
        echo "check-provenance: shallow clone, first-commit rule cannot run (use fetch-depth: 0)" >&2
        exit 1
    fi
fi

fail() {
    echo "  ❌ $1: $2" >&2
    EXIT_CODE=1
}

# Print the frontmatter block (without the --- fences), or nothing.
frontmatter() {
    awk 'NR==1 && $0!="---" {exit} NR==1 {next} $0=="---" {exit} {print}' "$1"
}

# Top-level scalar value of a frontmatter key, quotes stripped.
scalar() {
    local key="$1"
    sed -n -E "s/^${key}:[[:space:]]*['\"]?([^'\"#]*)['\"]?[[:space:]]*(#.*)?$/\1/p" | head -n1 | sed -E 's/[[:space:]]+$//'
}

# Authors as a sorted, comma-joined list; block or inline YAML list.
authors() {
    awk '
        /^authors:[[:space:]]*\[/ {
            sub(/^authors:[[:space:]]*\[/, ""); sub(/\].*$/, "")
            n = split($0, a, ","); for (i = 1; i <= n; i++) { gsub(/[[:space:]"]/, "", a[i]); if (a[i] != "") print a[i] }
            exit
        }
        /^authors:[[:space:]]*$/ { inlist = 1; next }
        inlist && /^[[:space:]]+-[[:space:]]*/ { v = $0; sub(/^[[:space:]]+-[[:space:]]*/, "", v); gsub(/[[:space:]"]/, "", v); print v; next }
        inlist { exit }
    ' | tr -d "'" | sort | paste -sd, -
}

expected_authors() {
    case "$1" in
        human) echo "$HUMAN_AUTHOR" ;;
        human_edited) printf '%s\n%s\n' "$HUMAN_AUTHOR" "$MACHINE_AUTHOR" | sort | paste -sd, - ;;
        machine) echo "$MACHINE_AUTHOR" ;;
    esac
}

# Author of the commit that first added a file, following renames only.
# `git log --follow` also follows copies, which ties a new page to any
# similar older page, so renames are traced one add commit at a time.
first_author() {
    local path="$1" rev="HEAD" add old
    while :; do
        add=$(git log --diff-filter=A --format=%H "$rev" -- "$path" 2>/dev/null | tail -n1)
        [[ -n "$add" ]] || return 0
        old=$(git show -M --diff-filter=R --name-status --format= "$add" |
            awk -F'\t' -v p="$path" '$3 == p {print $2; exit}')
        if [[ -z "$old" ]] || ! git rev-parse -q --verify "$add^" >/dev/null; then
            git log -1 --format=%an "$add"
            return 0
        fi
        path="$old"
        rev="$add^"
    done
}

check_file() {
    local file="$1"

    [[ "$file" == docs/*.md ]] || return 0
    [[ "$file" == docs/includes/* ]] && return 0

    local fm provenance
    fm=$(frontmatter "$file")
    provenance=$(scalar provenance <<<"$fm")

    case "$provenance" in
        human | human_edited | machine) ;;
        "")
            fail "$file" "missing frontmatter key 'provenance' (human | human_edited | machine)"
            return
            ;;
        *)
            fail "$file" "invalid provenance '$provenance' (human | human_edited | machine)"
            return
            ;;
    esac

    if [[ "$file" == docs/blog/posts/* ]]; then
        local got want
        got=$(authors <<<"$fm")
        want=$(expected_authors "$provenance")
        if [[ "$got" != "$want" ]]; then
            fail "$file" "provenance '$provenance' needs authors [$want], found [$got]"
        fi
    fi

    if [[ $IN_GIT -eq 1 && "$provenance" == "human" ]]; then
        local first
        first=$(first_author "$file")
        if [[ "$first" == "$BOT_AUTHOR" ]]; then
            fail "$file" "first commit is by $BOT_AUTHOR, so it cannot claim provenance 'human'"
        fi
    fi
}

for file in "$@"; do
    if [[ -f "$file" ]]; then
        check_file "$file"
    fi
done

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "" >&2
    echo "Provenance rules: CONTRIBUTING.md, section 'Provenance'." >&2
fi

exit $EXIT_CODE
