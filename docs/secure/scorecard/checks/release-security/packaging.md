---
description: >-
  Complete remediation guide for OpenSSF Scorecard Packaging check.
  Publish to package registries for wider distribution and trust.
tags:
  - scorecard
  - packaging
  - registries
---

# Packaging Check

!!! tip "Key Insight"
    Package publishing automation reduces human error and improves supply chain security.

**Target**: 10/10 by publishing to package manager

**What it checks**: Whether project is published to language-specific package manager (npm, PyPI, Go modules, RubyGems, Maven Central, crates.io, NuGet).

**Why it matters**: Package managers provide centralized distribution, version management, and dependency resolution. Publishing signals production-ready code and makes consumption easier for users.

## Understanding the Score

Scorecard detects:

- Package registry metadata (npm, PyPI, Go, etc.)
- GitHub Release artifacts matching package names
- Automated publishing workflows

**Scoring**:

- **10/10**: Package published to appropriate registry for project language
- **0/10**: No package registry detected

**Note**: This check is binary (0 or 10). You either publish packages or you don't.

## Quick Start by Language

Choose your package registry:

- [Go Modules](./packaging/go-modules.md): Automatic via git tags
- [npm](./packaging/npm.md): JavaScript/TypeScript packages
- [PyPI](./packaging/pypi.md): Python packages
- [Container Registries](./packaging/containers.md): Docker images

## Detailed Guides

## Related Content

- [Signed-Releases](./signed-releases.md): Sign published packages
- [License](./license.md): OSI-approved license for packages
- [Score Progression Tier 2](../../score-progression/tier-2.md): Publishing workflows
