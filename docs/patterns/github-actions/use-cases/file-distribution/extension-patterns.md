---
title: Extension Patterns
description: >-
  Extend file distribution with multi-file copies, conditional logic, template rendering, directory operations, and selective repository targeting with GraphQL.
---

# Extension Patterns

Extend the basic file distribution workflow for more complex scenarios.

!!! tip "General Pattern"

    These extensions build on the [Matrix Distribution](../../../../patterns/architecture/matrix-distribution/index.md) pattern. See that page for the underlying concepts.

---

## Multiple File Distribution

```yaml
- name: Copy files
  run: |
    cp file1.txt target/
    cp file2.yaml target/
    cp file3.md target/
```

## Conditional Distribution

Distribute different files based on repository type:

```yaml
- name: Check repository type
  id: check_type
  working-directory: target
  run: |
    if [ -f "package.json" ]; then
      echo "type=nodejs" >> $GITHUB_OUTPUT
    elif [ -f "pom.xml" ]; then
      echo "type=java" >> $GITHUB_OUTPUT
    fi

- name: Copy appropriate files
  run: |
    if [ "${{ steps.check_type.outputs.type }}" = "nodejs" ]; then
      cp node-config.json target/
    elif [ "${{ steps.check_type.outputs.type }}" = "java" ]; then
      cp java-config.xml target/
    fi
```

## Template Rendering

Substitute variables in templates:

```yaml
- name: Render template
  run: |
    sed "s/{{REPO_NAME}}/${{ matrix.repo.name }}/g" template.txt > target/file.txt
```

### Advanced Template Rendering

Use envsubst for multiple variables:

```yaml
- name: Render template
  env:
    REPO_NAME: ${{ matrix.repo.name }}
    ORG_NAME: your-org
    TIMESTAMP: ${{ github.event.head_commit.timestamp }}
  run: |
    envsubst < template.txt > target/file.txt
```

## Directory Distribution

Distribute entire directories:

```yaml
- name: Copy directory
  run: |
    cp -r source-dir/* target/destination-dir/
```

## File Transformation

Transform files during distribution:

```yaml
- name: Transform and copy
  run: |
    # Convert YAML to JSON
    yq -o=json source.yaml > target/config.json

    # Minify JavaScript
    terser source.js -o target/script.min.js
```

## Selective Repository Targeting

Filter repositories by criteria:

```yaml
- name: Query repositories with topic
  run: |
    REPOS=$(gh api graphql -f query='
    {
      search(query: "org:your-org topic:needs-config", type: REPOSITORY, first: 100) {
        nodes {
          ... on Repository {
            name
            defaultBranchRef { name }
          }
        }
      }
    }' --jq '.data.search.nodes | map({name: .name, default_branch: .defaultBranchRef.name})')
```
