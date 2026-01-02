---
description: >-
  Evidence collection for SDLC hardening. Branch protection archival, PR review tracking, workflow logs, and integration with CI gates for comprehensive audit trail generation.
tags:
  - audit
  - evidence
  - compliance
  - documentation
  - archival
---

# Phase 2: Evidence Collection

Collect proof that controls are working.

---

## Integration with Branch Protection

### Update Required Checks

Update branch protection to require new CI checks:

```bash
# Add new required status checks
gh api --method PATCH repos/org/repo/branches/main/protection \
  --field required_status_checks[contexts][]=ci/tests \
  --field required_status_checks[contexts][]=ci/lint \
  --field required_status_checks[contexts][]=ci/security-scan \
  --field required_status_checks[contexts][]=ci/sbom-generation
```

Verify configuration:

```bash
gh api repos/org/repo/branches/main/protection | \
  jq '.required_status_checks.contexts'
# Should include: ci/tests, ci/lint, ci/security-scan, ci/sbom-generation
```

---

## Metrics to Track

### CI Gate Effectiveness

**Metrics**:

- Pull requests blocked by failing tests
- Pull requests blocked by security scans
- Pull requests blocked by lint violations
- Average time to fix blocked PRs

### SBOM Coverage

**Metrics**:

- Percentage of builds with SBOM generated
- Average dependencies per SBOM
- Time to identify affected services during CVE response

### SLSA Adoption

**Metrics**:

- Percentage of releases with provenance
- Provenance verification success rate
- Time to generate provenance per release

!!! success "Target Metrics"
    - CI gate block rate: 5-10% (catching real issues)
    - SBOM generation: 100% of builds
    - SLSA provenance: 100% of releases
    - Evidence collection: 100% success rate monthly

---

## Evidence Collection Workflow

### Automated Collection

- [ ] **Collect and archive evidence automatically**

  ```yaml
  # .github/workflows/collect-evidence.yml
  name: Collect Audit Evidence
  on:
    schedule:
      - cron: '0 0 1 * *'  # Monthly

  jobs:
    archive:
      runs-on: ubuntu-latest
      steps:
        - name: Collect branch protection config
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          run: |
            mkdir -p evidence/$(date +%Y-%m)
            gh api repos/org/repo/branches/main/protection \
              > evidence/$(date +%Y-%m)/branch-protection.json

        - name: Collect PR review data
          run: |
            gh api 'repos/org/repo/pulls?state=closed&base=main&per_page=100' \
              > evidence/$(date +%Y-%m)/merged-prs.json

        - name: Archive to GCS
          run: |
            gsutil -m cp -r evidence/* gs://audit-evidence/

  ```

  **How to validate**:

  ```bash
  # Verify evidence files exist
  gsutil ls gs://audit-evidence/2025-01/
  # Should show: branch-protection.json, merged-prs.json
  ```

  **Why it matters**: Auditors will ask for historical evidence. Automated collection ensures it exists when needed.

---

## Common Issues and Solutions

**Issue**: Evidence collection workflow fails silently

**Solution**: Add notification on failure:

```yaml
- name: Notify on failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Evidence collection failed'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Related Patterns

- **[CI/CD Gates](ci-gates.md)** - Pipeline enforcement
- **[Phase 2 Overview →](index.md)** - Automation phase summary
- **[Phase 4: Advanced →](../phase-4/index.md)** - Advanced evidence collection

---

*Evidence collected. CI gates tracked. Metrics monitored. Audit trail is comprehensive.*
