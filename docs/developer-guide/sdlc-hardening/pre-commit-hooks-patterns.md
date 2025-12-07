---
title: Pre-commit Hooks - Implementation Guide
description: >-
  Implement pattern detection hooks, manage exceptions, and integrate with CI/CD
  for comprehensive pre-commit security enforcement.
---

# Pre-commit Hooks - Implementation Guide

## Implementation: Pattern Detection Hook

### The Hook Definition

```yaml
# .pre-commit-hooks.yaml
- id: forbidden-tech
  name: Block Forbidden Technologies
  description: Enforce vendor-neutral technology choices
  entry: forbidden-tech-check
  language: golang
  files: \.(md|yaml|yml|sh|tf|Dockerfile|Containerfile)$
  pass_filenames: true
```

!!! tip "Pre-commit Hooks - Pattern Detection"
    Implementation patterns for pre-commit security enforcement. Start with local validation before enabling CI enforcement.

### The Detection Logic

```go
package main

import (
    "bufio"
    "fmt"
    "os"
    "regexp"
    "strings"
)

var forbiddenPatterns = map[string][]string{
    "Docker": {
        `(?i)\bdocker\s+build\b`,
        `(?i)\bdocker\s+push\b`,
        `(?i)\bFROM\s+.*docker\.io`,
        `(?i)Docker\s+Hub`,
    },
    "Terraform": {
        `(?i)\bterraform\s+(init|plan|apply)`,
        `(?i)\.tf$`,
        `(?i)terraform\s+{`,
    },
    "AWS-specific": {
        `(?i)\baws_\w+\b`,
        `(?i)AWS::\w+`,
        `(?i)\.amazonaws\.com`,
    },
}

var exceptions = map[string]bool{
    "docs/migration-guides/": true,  // Historical reference
    "CHANGELOG.md":           true,  // Release notes
}

func checkFile(path string) ([]Violation, error) {
    // Check exceptions
    for exception := range exceptions {
        if strings.Contains(path, exception) {
            return nil, nil
        }
    }

    file, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    defer file.Close()

    var violations []Violation
    scanner := bufio.NewScanner(file)
    lineNum := 0

    for scanner.Scan() {
        lineNum++
        line := scanner.Text()

        for tech, patterns := range forbiddenPatterns {
            for _, pattern := range patterns {
                re := regexp.MustCompile(pattern)
                if re.MatchString(line) {
                    violations = append(violations, Violation{
                        File:       path,
                        Line:       lineNum,
                        Technology: tech,
                        Match:      re.FindString(line),
                    })
                }
            }
        }
    }

    return violations, scanner.Err()
}

type Violation struct {
    File       string
    Line       int
    Technology string
    Match      string
}

func main() {
    if len(os.Args) < 2 {
        fmt.Fprintln(os.Stderr, "Usage: forbidden-tech-check <files...>")
        os.Exit(1)
    }

    var allViolations []Violation

    for _, path := range os.Args[1:] {
        violations, err := checkFile(path)
        if err != nil {
            fmt.Fprintf(os.Stderr, "Error checking %s: %v\n", path, err)
            os.Exit(2)
        }
        allViolations = append(allViolations, violations...)
    }

    if len(allViolations) > 0 {
        fmt.Fprintln(os.Stderr, "")
        fmt.Fprintln(os.Stderr, "FORBIDDEN TECHNOLOGY DETECTED")
        fmt.Fprintln(os.Stderr, "")

        for _, v := range allViolations {
            fmt.Fprintf(os.Stderr, "  %s:%d - %s: %s\n",
                v.File, v.Line, v.Technology, v.Match)
        }

        fmt.Fprintln(os.Stderr, "")
        fmt.Fprintln(os.Stderr, "See content policies: README.md")
        fmt.Fprintln(os.Stderr, "")

        os.Exit(1)
    }
}
```

---

## The Developer Experience

### When It Works

```bash
$ git commit -m "Add deployment guide"
Block Forbidden Technologies................................Passed
[main abc123d] Add deployment guide
 1 file changed, 42 insertions(+)
```

Clean commits. No friction.

### When It Catches Something

```bash
$ git commit -m "Add docker build script"
Block Forbidden Technologies................................Failed
- hook id: forbidden-tech
- exit code: 1

FORBIDDEN TECHNOLOGY DETECTED

  scripts/build.sh:12 - Docker: docker build
  scripts/build.sh:15 - Docker: docker push

See content policies: README.md
```

The commit is blocked. Fix it first.

---

## Defense in Depth: Hook + CI

Pre-commit hooks are local. Developers can bypass with `--no-verify`. Defense in depth requires CI validation:

```yaml
# .github/workflows/security-gates.yml
name: Security Gates

on: [pull_request]

jobs:
  forbidden-tech:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run pre-commit checks
        uses: pre-commit/action@v3.0.0
        with:
          extra_args: forbidden-tech --all-files
```

Same tool, same rules. Local enforcement with CI backstop.

---

## Managing Legitimate Exceptions

Not all mentions are violations. Migration guides reference old tech. Troubleshooting docs quote error messages.

### Path-Based Exceptions

```go
var exceptions = map[string]bool{
    "docs/migration-guides/":     true,
    "docs/troubleshooting/":      true,
    "CHANGELOG.md":               true,
}
```

### Inline Suppression

```yaml
# pre-commit-suppress: forbidden-tech
FROM docker.io/library/python:3.11
```

Parse comments to skip specific lines:

```go
if strings.Contains(line, "pre-commit-suppress: forbidden-tech") {
    continue
}
```

### Exception Reporting

Log exceptions for audit:

```go
if isException(path) {
    fmt.Fprintf(os.Stdout, "EXCEPTION: %s (allowed path)\n", path)
}
```

---

## Patterns to Detect

### Secrets

```go
secretPatterns := []string{
    `(?i)(password|passwd|pwd)\s*[=:]\s*[^\s]+`,
    `(?i)(api[_-]?key|apikey)\s*[=:]\s*[^\s]+`,
    `-----BEGIN\s+(RSA\s+)?PRIVATE\sKEY-----`,
    `ghp_[a-zA-Z0-9]{36}`,  // GitHub token
}
```

### Hardcoded URLs

```go
hardcodedURLs := []string{
    `https?://(?!example\.com|localhost)[\w\-\.]+\.\w+/[\w\-\.]+`,
}
```

### Debugging Code

```go
debugPatterns := []string{
    `console\.log\(`,
    `fmt\.Println\(`,
    `print\(.*\)`,
}
```

---
