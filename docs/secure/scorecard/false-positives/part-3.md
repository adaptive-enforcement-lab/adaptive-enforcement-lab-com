## OpenSSF Best Practices

While this repository is private, we follow OpenSSF Best Practices:
- [x] Security policy documented
- [x] Vulnerability reporting process
- [x] HTTPS for all endpoints
[... full checklist ...]
```

Makes public transition easier.

---

### Vulnerabilities

#### False Positive: Dev Dependencies

**Pattern**: Scorecard flags vulnerabilities in `devDependencies`.

```json
{
  "devDependencies": {
    "vulnerable-test-tool": "1.0.0"  // Has known CVE
  }
}
```

**Why flagged**: Scorecard doesn't distinguish dev from production dependencies.

**Why sometimes false positive**: Dev dependencies don't ship to production.

**Resolution**:

#### Option 1: Fix anyway (recommended)

```bash
# Update dev dependencies too
npm audit fix
```

Simpler than explaining the difference.

#### Option 2: Document if unfixable

```markdown
# Known Vulnerabilities in Dev Dependencies

- vulnerable-test-tool@1.0.0: CVE-2023-1234
  - Impact: Dev environment only, not in production
  - Mitigation: No fix available, tool only used in CI
  - Risk: Low - isolated CI environment
```

**Expected score**: 10/10 if fixed, lower if documented

---

### Token-Permissions

#### False Positive: Reusable Workflows

**Pattern**: Scorecard flags workflows that call reusable workflows.

```yaml
# caller.yml
jobs:
  call-reusable:
    uses: ./.github/workflows/reusable.yml@main
    # Permissions inherited from reusable workflow
```

**Why flagged**: Scorecard may not follow the permission chain.

**Resolution**:

Explicitly set permissions in caller:

```yaml
# caller.yml
jobs:
  call-reusable:
    permissions:
      contents: read  # Explicit, even though reusable sets its own
    uses: ./.github/workflows/reusable.yml@main
```

**Expected score**: 10/10 with explicit permissions

---

## Release & Distribution Checks

### Signed-Releases

#### False Positive: No Releases Yet

**Pattern**: New repositories with no releases get 0/10.

**Why flagged**: No release artifacts to sign.

**Why false positive**: Can't sign releases that don't exist.

**Resolution**: Accept 0/10 until first release.

**Planning**: Implement SLSA provenance before first release:

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write
  id-token: write

jobs:
  release:
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
```

First release will immediately achieve 10/10.

---

### Packaging

#### False Positive: Library vs Application

**Pattern**: Applications flagged for not publishing packages.

**Why flagged**: Scorecard expects all projects to publish to package registries.

**Why false positive**:

- End-user applications don't publish packages
- Internal tools not meant for distribution
- Service applications deployed as containers

**Resolution**:

**For applications**: Accept 0/10 or low score.

**For libraries**: Publish to appropriate registry:

- Go: Tagging is publishing (`git tag v1.0.0`)
- npm: `npm publish`
- PyPI: `twine upload`
- Containers: Push to registry

---

### License

#### False Positive: Proprietary/Private Code

**Pattern**: Private repositories flagged for no OSS license.

**Why flagged**: Scorecard expects OSS license file.

**Why false positive**: Proprietary code shouldn't have OSS license.

**Resolution**:

Add `LICENSE` file with proprietary notice:

```text
# LICENSE

Copyright (c) 2026 YourCompany, Inc.

All rights reserved. This software is proprietary and confidential.
Unauthorized copying, distribution, or use is strictly prohibited.
```

Or create `LICENSE.md`:

```markdown
# License

This is proprietary software owned by YourCompany, Inc.
For licensing inquiries, contact legal@yourcompany.com.
```

**Expected score**: Scorecard may still give 0/10 (it expects OSI-approved licenses)

**When legitimate**: Private and proprietary code. Accept the score.

---

## Community Health Checks

### Contributors

#### False Positive: Solo-Maintained Projects

**Pattern**: One-person projects flagged for low contributor count.

**Why flagged**: Scorecard values multiple contributors for bus factor.

**Why false positive**: Solo maintenance is valid for personal projects.

**Resolution**: Accept the score. Quality > quantity.

**Alternative**: Encourage contributions:

- Add `CONTRIBUTING.md`
- Label issues as `good-first-issue`
- Respond quickly to PRs

**Expected score**: Improves over time as community grows

#### False Positive: Company Internal Projects

**Pattern**: Internal projects have few GitHub contributors.

**Why**: Most work happens in internal systems, synced to GitHub.

**Resolution**: Document contribution model:

```markdown
# CONTRIBUTING.md

This repository is maintained by YourCompany.
Contributions are managed through internal systems and synced to GitHub.

External contributions are welcome via pull requests.
```

---

### Maintained

#### False Positive: Stable/Complete Projects

**Pattern**: Complete projects with infrequent commits flagged.

**Why flagged**: No commits in 90 days suggests abandonment.

**Why false positive**: Some projects are complete and stable.

**Resolution**:

#### Option 1: Regular maintenance commits

```bash
# Monthly dependency updates via Renovate
# Keeps commit history active
```

#### Option 2: Document maintenance status

```markdown
# README.md

## Maintenance Status

This project is **complete and stable**.
Infrequent commits reflect stability, not abandonment.

Maintained by: @yourname
Last reviewed: 2026-01-02
```

#### Option 3: Archive if truly complete

```bash
# If no further development planned
gh repo archive your-org/your-repo
```

Scorecard will still flag it, but users know it's intentional.

---

## When to Open Scorecard Issues

Report false positives to help improve Scorecard heuristics.

### Worth Reporting

**Pattern is widespread**:

```text
Example: All SLSA projects hit this false positive
```

**Clear safe pattern exists**:

```text
Example: pull_request_target with no checkout is safe
Already documented in GitHub security best practices
```

**Tool should recognize alternatives**:

```text
Example: Clippy for Rust is equivalent to CodeQL for other languages
Request: Recognize `cargo clippy` as SAST
```

### Not Worth Reporting

**Edge case specific to your project**:

```text
Example: Our custom build system doesn't fit standard patterns
```

**Already documented in Scorecard limitations**:

```text
Check: https://github.com/ossf/scorecard/blob/main/docs/checks.md
Known limitation: Admin bypass detection
```

**Requires context Scorecard can't have**:

```text
Example: This binary is safe because we audited it
Scorecard can't verify human audit processes
```

---
