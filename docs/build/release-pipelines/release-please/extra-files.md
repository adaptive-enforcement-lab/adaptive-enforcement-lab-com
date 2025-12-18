---
description: >-
  Track versions in arbitrary files using x-release-please-version annotations. Configure extra-files for documentation, APIs, and distributed content versioning.
---

# Extra-Files

Track versions in arbitrary files using the `extra-files` configuration.

---

## Configuration

```json
{
  "packages": {
    ".": {
      "release-type": "simple",
      "extra-files": [
        {
          "type": "generic",
          "path": "README.md",
          "glob": false
        },
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

---

## Version Annotation

Files must contain the `x-release-please-version` annotation:

```markdown
---
title: Contributing Guidelines
version: 2.5.5 # x-release-please-version
---
```

Release-please finds this comment and updates the version number on the same line.

---

## Use Cases

| Use Case | File | Annotation |
| ---------- | ------ | ------------ |
| Documentation version | `README.md` | `Version: 1.0.0 # x-release-please-version` |
| Distributed guidelines | `CONTRIBUTING.md` | `version: 1.0.0 # x-release-please-version` |
| API version header | `openapi.yaml` | `version: '1.0.0' # x-release-please-version` |

!!! warning "Distribution Side Effects"

    When extra-files are distributed to other repositories, version bumps
    trigger file changes. Use [content comparison](../../../patterns/github-actions/use-cases/work-avoidance/content-comparison.md)
    to avoid creating PRs for version-only changes.

---

## Package Limitations

Release-please packages are **directory-based**. Each package path must point to a directory, not a single file.

### What Doesn't Work

```json
{
  "packages": {
    ".": { "release-type": "simple" },
    "CONTRIBUTING.md": {
      "release-type": "simple",
      "component": "contributing"
    }
  }
}
```

This fails because `CONTRIBUTING.md` is a file, not a directory.

### Why This Limitation Exists

1. **Changelogs need location** - `CHANGELOG.md` must live somewhere
2. **Version files need context** - `package.json`, `Chart.yaml` exist in directories
3. **Monorepos are directories** - Each package is a self-contained unit

### The Solution

Use `extra-files` to track versions in single files:

```json
{
  "packages": {
    ".": {
      "release-type": "simple",
      "extra-files": [
        { "type": "generic", "path": "CONTRIBUTING.md", "glob": false }
      ]
    }
  }
}
```

The file shares the parent package's version. For independent versioning of single files, consider a directory wrapper or a different tool.

---

## Related

- [Release-Please Overview](index.md) - Configuration basics
- [Content Comparison](../../../patterns/github-actions/use-cases/work-avoidance/content-comparison.md) - Skip version-only changes
- [Customizing Release-Please](https://github.com/googleapis/release-please/blob/main/docs/customizing.md) - Official extra-files documentation
