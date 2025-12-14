---
date: 2025-11-30
authors:
  - mark
categories:
  - CI/CD
  - GitHub Actions
  - Engineering Patterns
description: >-
  Release-please packages are directories, not files.
  When I tried to track CONTRIBUTING.md separately, I learned why.
slug: what-release-please-cant-do
---

# What Release-Please Can't Do

I wanted to version CONTRIBUTING.md independently from the main project. Separate changelog. Separate release cycle. Separate tags.

Release-please said no.

<!-- more -->

---

## The Goal

!!! info "The Scenario"
    Our CONTRIBUTING.md lives in a central repository and gets distributed to 75+ other repos.

When we update the guidelines, we wanted:

1. A dedicated changelog for contribution guideline changes
2. Tags like `contributing-1.0.0`, `contributing-1.1.0`
3. Independent versioning from the main platform

This seemed reasonable. Release-please supports [monorepo configurations](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) with multiple packages. Why not add CONTRIBUTING.md as a package?

---

## The Attempt

```json
{
  "packages": {
    ".": {
      "release-type": "simple",
      "component": "platform"
    },
    "contributing": {
      "release-type": "simple",
      "component": "contributing-guidelines"
    }
  }
}
```

Error: `contributing` is not a directory.

---

## The Discovery

!!! warning "Key Limitation"
    Release-please packages are **directory-based**. The path must point to a directory, not a single file.

The configuration path must point to a directory containing versionable files.

From the [release-please documentation](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md):

> Each package path should be a directory relative to the repository root.

A single file at the repository root cannot be a package. Workarounds like:

- Creating a `contributing/` directory with just the file
- Using symlinks
- Nested manifests

All create more problems than they solve.

---

## The Solution

Accept the limitation. Use `extra-files` instead:

```json
{
  "packages": {
    ".": {
      "release-type": "simple",
      "extra-files": [
        {
          "type": "generic",
          "path": "CONTRIBUTING.md",
          "glob": false
        }
      ]
    }
  }
}
```

The file gets its version updated alongside the main package. Add the annotation:

```markdown
---
title: Contributing Guidelines
version: 1.4.2 # x-release-please-version
---
```

Release-please finds `x-release-please-version` and updates the number.

---

## What This Means

| Want | Reality |
| ------ | --------- |
| Independent versioning | Shares version with parent package |
| Separate changelog | Changes appear in main changelog |
| Dedicated tags | No separate tags |
| Per-file release cycle | Releases with everything else |

For most use cases, this is fine. The file version updates automatically. Distribution workflows can read it. Consumers know which version they have.

If you truly need independent versioning for a single file, you need a different tool or a directory wrapper.

---

## The Changelog Compromise

Even without independent versioning, you can control what appears in changelogs. Hide noise with scope filtering:

```json
{
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "docs", "section": "Documentation" },
    { "type": "chore", "scope": "deps", "section": "Dependencies", "hidden": true },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "ci", "section": "CI/CD", "hidden": true }
  ]
}
```

The `scope` field targets specific commit patterns. `chore(deps): bump lodash` gets hidden. `chore: update build config` appears under Maintenance.

---

## Schema Validation

One more lesson: **always validate against the schema**.

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
}
```

I initially tried `release-name` to customize the release title. The option doesn't exist. It was a hallucination. The schema would have caught it immediately.

---

## When Directory-Based Makes Sense

The limitation exists for good reasons:

1. **Changelogs need location** - Where does `CHANGELOG.md` go for a single file?
2. **Version files need context** - `package.json`, `Chart.yaml`, `version.txt` live in directories
3. **Monorepos are directories** - Each package is a self-contained unit

Release-please is built for packages, not files. Once I accepted that, the configuration became obvious.

---

## Deep Dive

- [Release-Please Setup](../../operator-manual/github-actions/use-cases/release-pipelines/release-please/index.md) - Configuration options including extra-files
- [Release-Please Manifest Documentation](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) - Official monorepo guide
- [Customizing Release-Please](https://github.com/googleapis/release-please/blob/main/docs/customizing.md) - Extra-files and version annotations

---

*CONTRIBUTING.md now shares our platform version. It's not what I originally wanted, but it's the right tool for the job.*
