---
date: 2025-12-25
authors:
  - mark
categories:
  - CI/CD
  - Code Quality
  - DevSecOps
description: >-
  Components configured. Codecov showed "No report uploaded." Paths looked correct. Glob patterns vs regex syntax.
slug: regex-that-fixed-everything
---

# The Regex That Fixed Everything

Codecov components were configured. Five components, clean breakdown by package.

Codecov dashboard: **"No report uploaded"** for all components.

Coverage uploaded successfully. Components showed zero coverage.

The paths looked correct.

<!-- more -->

---

## The Setup

We wanted component-based coverage reporting:

- **CLI**: `cmd/readability/`
- **Analyzer**: `pkg/analyzer/`
- **Config**: `pkg/config/`
- **Markdown Parser**: `pkg/markdown/`
- **Output**: `pkg/output/`

Each component tracks coverage independently. Components show which parts need attention.

---

## The Configuration (Wrong)

`codecov.yml` configuration:

```yaml
component_management:
  individual_components:
    - component_id: cli
      name: CLI
      paths:
        - cmd/**

    - component_id: analyzer
      name: Analyzer
      paths:
        - pkg/analyzer/**

    - component_id: config
      name: Configuration
      paths:
        - pkg/config/**
```

This looks right. GitHub Actions uses glob patterns. This matches GitHub workflow syntax.

**Result**: All components showed "No report uploaded"

---

## The Confusion

Coverage uploaded successfully:

```yaml
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v5
  with:
    files: ./coverage.out
```

✅ Coverage file uploaded
✅ Total coverage calculated (99%)
❌ Components empty

Checked:

- ✅ Component IDs unique
- ✅ Paths non-overlapping
- ✅ Coverage file includes all packages
- ✅ Codecov token valid

Everything validated. Components still empty.

---

## The Discovery

Codecov documentation buried the detail: **Component paths use regex, not glob patterns.**

GitHub Actions uses glob syntax:

- `**/*.go` matches all Go files
- `cmd/**` matches everything under cmd/

Codecov uses **regex syntax**:

- `.*\.go$` matches all Go files
- `cmd/.*` matches everything under cmd/

**Our paths were glob. Codecov expected regex.**

The fix:

```yaml
component_management:
  individual_components:
    - component_id: cli
      name: CLI
      paths:
        - "cmd/readability/.*"  # Regex, not glob

    - component_id: analyzer
      name: Analyzer
      paths:
        - "pkg/analyzer/.*"  # Regex, not glob
```

**Result**: All components showed coverage breakdown

---

## The Pattern

### Before (Glob - Wrong for Codecov)

```yaml
paths:
  - cmd/**              # Glob pattern
  - pkg/analyzer/**     # Glob pattern
```

### After (Regex - Correct for Codecov)

```yaml
paths:
  - "cmd/readability/.*"    # Regex pattern
  - "pkg/analyzer/.*"       # Regex pattern
```

### Escaping Special Characters

```yaml
# Glob (GitHub Actions)
paths:
  - "*.go"

# Regex (Codecov)
paths:
  - ".*\\.go$"  # Escape the dot, anchor with $
```

---

## The Comparison Table

| Pattern Type | Syntax Example  | Used By                          |
| ------------ | --------------- | -------------------------------- |
| **Glob**     | `cmd/**/*.go`   | GitHub Actions, most CI tools    |
| **Regex**    | `^cmd/.*\.go$`  | Codecov components, some linters |

**Same paths. Different syntax. Silent failure.**

---

## The Debugging Journey

1. **Components empty**: "No report uploaded"
2. **Check coverage**: Upload successful, 99% total
3. **Check paths**: Look correct (glob syntax)
4. **Re-read docs**: Found "paths use regex" note
5. **Test regex**: Changed `cmd/**` → `"cmd/readability/.*"`
6. **Success**: Components populate with coverage data

Time wasted: 3 hours
Fix: Change glob to regex
Documentation location: Buried in examples

---

## The Silent Failure

Codecov didn't error. It just silently failed to match paths.

**What we expected**:

```text
Warning: Component 'cli' path 'cmd/**' invalid (must be regex)
```

**What we got**:

```text
No report uploaded
```

The error message suggests upload failure, not path mismatch.

---

## The Lesson

**Different tools, different path syntax.**

- GitHub Actions: glob (`**/*.go`)
- Codecov components: regex (`.*\.go$`)
- .gitignore: glob
- .dockerignore: glob
- ESLint: glob
- Some linters: regex

**Don't assume.** Check documentation for path syntax requirements.

When configuration "looks right" but doesn't work, check if you're using the wrong pattern type.

---

## The Working Configuration

```yaml
component_management:
  default_rules:
    statuses:
      - type: project
        target: 95%

  individual_components:
    - component_id: cli
      name: CLI
      paths:
        - "cmd/readability/.*"

    - component_id: analyzer
      name: Analyzer
      paths:
        - "pkg/analyzer/.*"

    - component_id: config
      name: Configuration
      paths:
        - "pkg/config/.*"

    - component_id: markdown
      name: Markdown Parser
      paths:
        - "pkg/markdown/.*"

    - component_id: output
      name: Output Formatters
      paths:
        - "pkg/output/.*"
```

**Result**: Component breakdown shows per-package coverage, trends, and gaps.

---

## What Changed

**Before**: "Components are configured correctly but Codecov shows nothing. Codecov must be broken."

**After**: "Codecov uses regex for component paths, not glob patterns. Different syntax for different tools."

The configuration was "right" for GitHub Actions. It was wrong for Codecov.

One syntax change fixed everything.

!!! tip "Implementation Guide"
    See [Coverage Enforcement](../../developer-guide/sdlc-hardening/testing/coverage-enforcement.md) for complete Codecov configuration including component-based reporting and CI integration.

---

## Related Patterns

- **[The Wall at 85%](2025-12-19-the-wall-at-eighty-five-percent.md)** - The coverage journey that needed component tracking
- **[Test Coverage as Security Signal](2025-12-21-coverage-as-security-signal.md)** - Why coverage components matter
- **[SDLC Hardening](2025-12-12-harden-sdlc-before-audit.md)** - Quality gates in audit context

---

*Components configured. Codecov showed nothing. Paths looked correct. Glob patterns failed. Regex patterns worked. Different tools, different syntax. Silent failure fixed by reading buried documentation.*
