---
description: >-
  Complete remediation guide for OpenSSF Scorecard Token-Permissions check.
  Use job-level permission scoping to minimize blast radius.
tags:

  - scorecard
  - github-actions
  - permissions
  - least-privilege

---

# Token-Permissions Check

!!! tip "Key Insight"
    Job-level permissions minimize blast radius from compromised workflows.

**Target**: 10/10 by using job-level permission scoping

**What it checks**: Whether GitHub Actions workflows grant minimal permissions to each job.

**Why it matters**: Workflow-level permissions grant all jobs maximum access. If any job is compromised (via malicious dependency or workflow injection), attackers get write access to repository and secrets. Job-level permissions limit blast radius.

## Quick Summary

Token-Permissions is **extensively covered** in existing documentation:

- **[Scorecard Compliance](../../scorecard-compliance.md)** - Complete patterns with before/after examples
- **[Scorecard Workflow Examples](../../scorecard-workflow-examples.md)** - Production workflows demonstrating job-level permissions
- **[Tier 1 Progression](../../score-progression/tier-1.md)** - Quick wins including Token-Permissions fix

**Core principle**: Empty permissions at workflow level, grant minimal permissions per job.

### Before: Workflow-Level Permissions

```yaml
name: Release

permissions:
  contents: write   # ALL jobs get this
  id-token: write   # ALL jobs get this

jobs:
  test:
    runs-on: ubuntu-latest
    steps:

      - run: go test ./...  # Doesn't need write!

```bash
**Result**: Token-Permissions alerts

### After: Job-Level Permissions

```yaml
name: Release

permissions: {}  # Empty at workflow level

jobs:
  test:
    permissions:
      contents: read  # Minimal for this job
    runs-on: ubuntu-latest
    steps:

      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - run: go test ./...

```bash
**Result**: Token-Permissions 10/10

### Common Permission Patterns

| Job Type | Required Permissions |
| -------- | -------------------- |
| Test | `contents: read` |
| Lint | `contents: read` |
| Build | `contents: read` |
| Release (upload assets) | `contents: write` |
| Signing (Cosign) | `contents: write`, `id-token: write` |
| SLSA provenance | `actions: read`, `id-token: write`, `contents: write` |
| PR comments | `pull-requests: write`, `contents: read` |

### Reference Documentation

For complete implementation details, see:

**[Scorecard Compliance → Token-Permissions](../../scorecard-compliance.md)**

Covers:

- Before/after examples
- All common permission patterns
- Troubleshooting permission errors
- Bulk migration strategies

**[Scorecard Workflow Examples](../../scorecard-workflow-examples.md)**

Production workflows demonstrating:

- Multi-job workflows with job-level permissions
- SLSA provenance with correct permissions
- Release workflows with signing

**Quick validation**:

```bash
# Check for workflow-level permissions

grep -r "^permissions:" .github/workflows/

# Should see only "permissions: {}" at workflow level

# Job-level permissions are indented under jobs

```bash
**Blog post**: [16 Alerts Cleared Overnight](../../../../blog/posts/2025-12-20-sixteen-alerts-overnight.md) - Real-world Token-Permissions mass fix

---

---

## Related Content

**Other Security Practices checks**:

- [Security-Policy](./security-policy.md) - Vulnerability disclosure process
- [CII-Best-Practices](./cii-best-practices.md) - OpenSSF Best Practices Badge
- [Vulnerabilities](./vulnerabilities.md) - Known CVE detection and remediation
- [Fuzzing](./fuzzing.md) - Automated fuzz testing

**Detailed guides**:

- [Scorecard Compliance → Token-Permissions](../../scorecard-compliance.md)
- [Scorecard Workflow Examples](../../scorecard-workflow-examples.md)
- [Tier 1 Progression](../../score-progression/tier-1.md)

**Blog posts**:

- [16 Alerts Cleared Overnight](../../../../blog/posts/2025-12-20-sixteen-alerts-overnight.md)

---

*Token-Permissions is a quick win. Move permissions from workflow level to job level for least-privilege access.*
