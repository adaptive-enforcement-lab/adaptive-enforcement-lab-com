---
description: >-
  Target type detection, include/exclude filtering, topic-based queries, and multi-file distribution patterns for selective GitHub Actions matrix processing.
---

# Conditional Distribution

Target type detection and filtering for selective distribution.

!!! tip "Right Content, Right Target"
    Detect target characteristics at runtime to distribute type-specific configurations. A Node.js project gets ESLint; a Go project gets golangci-lint.

---

## Target Type Detection

Distribute different content based on target characteristics:

```yaml
- name: Detect target type
  id: detect
  run: |
    if [ -f "package.json" ]; then
      echo "type=nodejs" >> $GITHUB_OUTPUT
    elif [ -f "pom.xml" ]; then
      echo "type=java" >> $GITHUB_OUTPUT
    elif [ -f "go.mod" ]; then
      echo "type=go" >> $GITHUB_OUTPUT
    else
      echo "type=unknown" >> $GITHUB_OUTPUT
    fi

- name: Apply Node.js config
  if: steps.detect.outputs.type == 'nodejs'
  run: cp configs/node/.eslintrc.json target/

- name: Apply Java config
  if: steps.detect.outputs.type == 'java'
  run: cp configs/java/checkstyle.xml target/
```

---

## Include/Exclude Logic

Filter targets based on criteria:

```yaml
- name: Check if target should be processed
  id: check
  run: |
    # Skip archived repos
    if [ "${{ matrix.target.archived }}" == "true" ]; then
      echo "skip=true" >> $GITHUB_OUTPUT
    else
      echo "skip=false" >> $GITHUB_OUTPUT
    fi

- name: Process target
  if: steps.check.outputs.skip == 'false'
  run: |
    # Only runs for non-archived targets
```

---

## Topic-Based Filtering

Query targets with specific topics:

```yaml
- name: Query repos with topic
  run: |
    REPOS=$(gh api graphql -f query='
    {
      search(query: "org:my-org topic:needs-config", type: REPOSITORY, first: 100) {
        nodes {
          ... on Repository {
            name
            defaultBranchRef { name }
          }
        }
      }
    }' --jq '.data.search.nodes | map({name: .name, default_branch: .defaultBranchRef.name})')

    echo "targets=$REPOS" >> $GITHUB_OUTPUT
```

---

## Multi-File Distribution

### Copy Multiple Files

```yaml
- name: Copy configuration files
  run: |
    cp -r source/configs/* target/.github/
    cp source/templates/CODEOWNERS target/
    cp source/templates/SECURITY.md target/
```

### Directory Sync

```yaml
- name: Sync directory
  run: |
    # Remove old files, copy new ones
    rm -rf target/.github/workflows/shared/
    cp -r source/workflows/shared/ target/.github/workflows/shared/
```

### Selective Copy

```yaml
- name: Copy based on target type
  run: |
    # Always copy base config
    cp source/base/* target/

    # Copy type-specific configs
    if [ "${{ steps.detect.outputs.type }}" == "nodejs" ]; then
      cp source/nodejs/* target/
    fi
```

---

## Related

- [Matrix Distribution Overview](index.md) - Core pattern
- [Template Rendering](template-rendering.md) - Variable substitution
