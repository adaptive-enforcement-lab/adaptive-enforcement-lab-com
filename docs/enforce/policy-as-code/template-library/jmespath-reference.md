---
description: >-
  Complete JMESPath function reference for Kyverno. String functions, array operations, filters, projections, and comparison operators.
tags:
  - kyverno
  - jmespath
  - policy-as-code
  - kubernetes
  - reference
---

# JMESPath Function Reference

Complete function reference for JMESPath in Kyverno policies. String functions, array operations, filters, and projections.

!!! abstract "TL;DR"
    Quick reference for all JMESPath functions and operators supported in Kyverno. Use with testing guide for best results.

---

## String Functions

| Function | Description | Example |
|----------|-------------|---------|
| `split(string, delimiter)` | Split string into array | `split(image, ':')[1]` |
| `join(delimiter, array)` | Join array into string | `join(',', tags)` |
| `contains(string, substring)` | Check substring existence | `contains(image, 'nginx')` |
| `starts_with(string, prefix)` | Check prefix | `starts_with(image, 'nginx')` |
| `ends_with(string, suffix)` | Check suffix | `ends_with(image, ':latest')` |
| `to_string(value)` | Convert to string | `to_string(port)` |

---

## Array Functions

| Function | Description | Example |
|----------|-------------|---------|
| `length(array)` | Count elements | `length(containers)` |
| `sort(array)` | Sort array | `sort(ports)` |
| `reverse(array)` | Reverse array | `reverse(items)` |
| `max(array)` | Maximum value | `max(ports)` |
| `min(array)` | Minimum value | `min(ports)` |
| `sum(array)` | Sum numeric array | `sum(values)` |

### Array Function Examples

```yaml
# Count containers
length(spec.containers)
# Input: [{"name": "nginx"}, {"name": "redis"}]
# Output: 2

# Find maximum port
max(spec.containers[*].ports[*].containerPort)
# Input: [80, 443, 8080]
# Output: 8080

# Sort container names
sort(spec.containers[*].name)
# Input: ["redis", "nginx", "app"]
# Output: ["app", "nginx", "redis"]
```

---

## Object Functions

| Function | Description | Example |
|----------|-------------|---------|
| `keys(object)` | Get object keys | `keys(metadata.labels)` |
| `values(object)` | Get object values | `values(metadata.annotations)` |
| `length(object)` | Count keys | `length(metadata.labels)` |

### Object Function Examples

```yaml
# Get all label keys
keys(metadata.labels)
# Input: {"app": "nginx", "env": "prod"}
# Output: ["app", "env"]

# Get all annotation values
values(metadata.annotations)
# Input: {"version": "1.0", "owner": "team"}
# Output: ["1.0", "team"]

# Count labels
length(metadata.labels)
# Input: {"app": "nginx", "env": "prod"}
# Output: 2
```

---

## Type Conversion Functions

| Function | Description | Example |
|----------|-------------|---------|
| `to_number(value)` | Convert to number | `to_number(replicas)` |
| `to_string(value)` | Convert to string | `to_string(port)` |
| `to_array(value)` | Convert to array | `to_array(item)` |

### Type Conversion Examples

```yaml
# Convert string to number
to_number("42")
# Output: 42

# Convert number to string
to_string(8080)
# Output: "8080"
```

---

## Comparison Operators

### Kyverno Operator Mapping

| JMESPath | Kyverno Operator |
|----------|-----------------|
| `==` | `operator: Equals` |
| `!=` | `operator: NotEquals` |
| `<` | `operator: LessThan` |
| `>` | `operator: GreaterThan` |
| `<=` | `operator: LessThanOrEquals` |
| `>=` | `operator: GreaterThanOrEquals` |

### Comparison Examples

```yaml
# Equals
key: "{{ request.object.spec.replicas }}"
operator: Equals
value: 3

# GreaterThan
key: "{{ request.object.spec.containers | length(@) }}"
operator: GreaterThan
value: 0

# In (check if value in list)
key: "{{ request.namespace }}"
operator: In
value: ["prod-east", "prod-west"]
```

---

## Filter Expressions

### Single Condition

```yaml
# Filter containers with specific image
containers[?image == 'nginx']

# Filter privileged containers
containers[?securityContext.privileged == `true`]

# Filter by null check
volumes[?hostPath]
```

### Multiple Conditions (AND)

```yaml
# Both conditions must be true
containers[?image == 'nginx' && securityContext.privileged == `true`]

# Check multiple nested fields
containers[?resources.requests.memory && resources.limits.memory]
```

### Multiple Conditions (OR)

```yaml
# Either condition can be true
containers[?image == 'nginx' || image == 'redis']

# Multiple image checks
containers[?image == 'nginx' || image == 'httpd' || image == 'apache']
```

### Negation (NOT)

```yaml
# Containers NOT running nginx
containers[?!(image == 'nginx')]

# Containers without privileged flag
containers[?!(securityContext.privileged == `true`)]
```

### Nested Filters

```yaml
# Filter volumes, then check types
volumes[?!configMap && !secret && !persistentVolumeClaim]

# Filter containers with specific port
containers[?ports[?containerPort == `80`]]
```

---

## Projection Patterns

### Single Field Projection

```yaml
# Project names
containers[*].name
# Input: [{"name": "nginx"}, {"name": "redis"}]
# Output: ["nginx", "redis"]

# Project images
containers[*].image

# Nested field projection
containers[*].securityContext.runAsUser
```

### Multiple Field Projection

```yaml
# Project multiple fields as array
containers[*].[name, image]
# Input: [{"name": "nginx", "image": "nginx:latest"}]
# Output: [["nginx", "nginx:latest"]]

# Project with nested fields
containers[*].[name, resources.limits.memory]
```

### Flatten Nested Arrays

```yaml
# Flatten ports across containers
containers[*].ports[*].containerPort
# Input: [[{containerPort: 80}, {containerPort: 443}]]
# Output: [80, 443]

# Flatten environment variables
containers[*].env[*].name
```

### Filter then Project

```yaml
# Filter nginx containers, project names
containers[?image == 'nginx'].name

# Filter and project multiple fields
containers[?securityContext.privileged == `true`].[name, image]

# Filter and project first result
containers[?name == 'app'].image | [0]
```

---

## Pipe Expressions

Pipe expressions chain operations left to right.

```yaml
# Split then access element
image | split(@, ':')[1]

# Filter, project, then get first
containers[?image == 'nginx'].name | [0]

# Multiple transformations
metadata.name | split(@, '-') | join('_', @)
# Input: "team-app-v1"
# Output: "team_app_v1"
```

---

## Common Expression Patterns

### Check for Existence

```yaml
# Check if field exists and is not empty
key: "{{ request.object.metadata.labels.app || '' }}"
operator: NotEquals
value: ""
```

### Default Values

```yaml
# Provide default for optional field
key: "{{ request.object.spec.replicas || `1` }}"

# String default
key: "{{ request.object.metadata.labels.tier || 'default' }}"
```

### Count Matching Items

```yaml
# Count privileged containers
key: "{{ request.object.spec.containers[?securityContext.privileged == `true`] | length(@) }}"
operator: Equals
value: 0
```

### Extract and Validate

```yaml
# Extract registry and validate
key: "{{ request.object.spec.containers[0].image | split(@, '/')[0] }}"
operator: In
value: ["registry.io", "backup.registry.io"]
```

---

## Quick Reference Card

### Most Used Functions

```yaml
# Count
length(array)

# Split
split(string, delimiter)[index]

# Contains
contains(string, substring)

# Filter
array[?condition]

# Project
array[*].field

# Default value
field || 'default'
```

---

## Next Steps

- **[JMESPath Testing →](jmespath-testing.md)** - Testing and debugging guide
- **[Enterprise JMESPath Examples →](jmespath-enterprise.md)** - Real-world policies
- **[JMESPath Advanced →](jmespath-advanced.md)** - Advanced patterns
- **[JMESPath Patterns (Core) →](jmespath-patterns.md)** - Core patterns
- **[Kyverno Templates Overview →](kyverno-templates.md)** - Complete template library
- **[Template Library Overview →](index.md)** - Back to main page
