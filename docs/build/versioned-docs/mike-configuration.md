---
description: >-
  Configure MkDocs Material with mike for multi-version documentation hosting. Includes version provider setup, local development workflows, and alias management.
---

# Mike Configuration

Configure MkDocs Material with mike for multi-version documentation hosting.

---

## Prerequisites

Install dependencies:

```bash
pip install mkdocs-material mike
```

Or in `requirements.txt`:

```text
mkdocs-material
mike
```

---

## MkDocs Configuration

Add version provider to `mkdocs.yml`:

```yaml
site_name: My Project
site_url: https://my-project.example.com

extra:
  version:
    provider: mike
    default: latest
```

The `default: latest` setting redirects the root URL to the `latest` alias.

---

## Version Selector

MkDocs Material automatically adds a version selector dropdown when it detects mike's `versions.json` file. No additional configuration required.

---

## Local Development

### Single Version

Standard development server (no versioning):

```bash
mkdocs serve
```

### Multi-Version Preview

Preview the versioned site locally:

```bash
# Build a version first
mike deploy dev

# Serve the versioned site
mike serve
```

!!! tip "First-Time Setup"

    Mike stores versions in the `gh-pages` branch. For a new project,
    you need at least one deployed version before `mike serve` works.

---

## Directory Structure

Mike expects standard MkDocs layout:

```text
project/
  mkdocs.yml
  docs/
    index.md
    ...
  requirements.txt
```

No special directories needed. Mike manages versions in the deployment target (gh-pages branch), not the source repository.

---

## Version JSON

Mike generates `versions.json` at the site root:

```json
[
  {"version": "1.2.3", "title": "1.2.3", "aliases": ["v1", "latest"]},
  {"version": "1.1.0", "title": "1.1.0", "aliases": []},
  {"version": "dev", "title": "dev", "aliases": []}
]
```

MkDocs Material reads this to populate the version selector.

---

## Related

- [Pipeline Integration](pipeline-integration.md) - CI/CD workflow setup
- [Version Strategies](version-strategies.md) - Aliasing patterns
- [MkDocs Material Documentation](https://squidfunk.github.io/mkdocs-material/) - Theme reference
