---
title: Template Rendering
description: >-
  Variable substitution with envsubst, jq transformations, YAML templating, and file format conversions for distributed configuration across multiple targets.
---
# Template Rendering

Variable substitution and file transformations for distributed content.

!!! tip "Templates Over Copies"
    Use templates with variable substitution to generate target-specific configurations. One template serves many targets.

---

## Simple Substitution

```yaml
- name: Render template
  run: |
    sed "s/{{REPO_NAME}}/${{ matrix.target.name }}/g" template.txt > target/config.txt
```

---

## Multi-Variable Substitution

Use `envsubst` for multiple variables:

```yaml
- name: Render template
  env:
    REPO_NAME: ${{ matrix.target.name }}
    ORG_NAME: my-org
    TIMESTAMP: ${{ github.event.head_commit.timestamp }}
    BRANCH: ${{ matrix.target.default_branch }}
  run: |
    envsubst < templates/config.template > target/config.yaml
```

Template file (`templates/config.template`):

```yaml
# Auto-generated for ${REPO_NAME}
# Generated: ${TIMESTAMP}

repository:
  name: ${REPO_NAME}
  organization: ${ORG_NAME}
  default_branch: ${BRANCH}
```

---

## Complex Transformations

For complex rendering, use dedicated tools:

```yaml
- name: Render with jq
  run: |
    jq --arg name "${{ matrix.target.name }}" \
       --arg org "my-org" \
       '.repository.name = $name | .repository.org = $org' \
       template.json > target/config.json

- name: Render with yq
  run: |
    yq eval ".metadata.name = \"${{ matrix.target.name }}\"" \
       template.yaml > target/config.yaml
```

---

## File Transformations

### Format Conversion

```yaml
- name: Convert YAML to JSON
  run: |
    yq -o=json source/config.yaml > target/config.json

- name: Convert JSON to YAML
  run: |
    yq -P source/config.json > target/config.yaml
```

### Minification

```yaml
- name: Minify assets
  run: |
    # JavaScript
    terser source/script.js -o target/script.min.js

    # CSS
    cssnano source/style.css target/style.min.css

    # JSON (remove whitespace)
    jq -c '.' source/data.json > target/data.json
```

### Content Injection

```yaml
- name: Inject content into existing file
  run: |
    # Add header to existing README
    cat source/header.md target/README.md > target/README.tmp
    mv target/README.tmp target/README.md
```

---

## Related

- [Matrix Distribution Overview](index.md) - Core pattern
- [Conditional Distribution](conditional-distribution.md) - Type detection
