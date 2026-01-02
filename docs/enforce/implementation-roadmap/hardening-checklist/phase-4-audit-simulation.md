---
description: >-
  Audit simulation for SDLC hardening. Mock audit timeline, document requests, sampling validation, gap analysis, and remediation process before real auditors arrive.
tags:
  - audit
  - simulation
  - testing
  - validation
  - readiness
---

# Phase 4: Audit Simulation

Run a mock audit before the real one.

---

## Mock Audit Timeline

!!! tip "Run This Quarterly"
    Don't wait for a real audit to discover gaps. Run this simulation quarterly. Treat it like a fire drill. The first time will be painful. By the third run, it's routine.

### Week 1: Document Request

Pretend auditors asked for:

- [ ] Branch protection config from 6 months ago
- [ ] PRs merged in Q4 with review metadata
- [ ] Commit signature coverage for last year
- [ ] SBOMs for 5 random production releases
- [ ] OpenSSF Scorecard history

Retrieve all evidence in under 1 hour.

**Validation**:

```bash
# Retrieve branch protection from 6 months ago
DATE_6M_AGO=$(date -d '6 months ago' +%Y-%m-%d)
gsutil ls gs://audit-evidence/$DATE_6M_AGO/ | grep branch-protection

# Get Q4 PR reviews
gsutil ls gs://audit-evidence/2024-{10,11,12}/ | grep merged-prs

# Check signature coverage
./scripts/calculate-signature-coverage.sh 2024-01-01 2024-12-31

# Retrieve random SBOMs
gsutil ls gs://audit-evidence/releases/*/sbom-*.json | shuf -n 5
```

---

### Week 2: Sampling

Sample 10 random PRs:

- [ ] Did they have required reviews?
- [ ] Were commits signed?
- [ ] Did CI checks pass?
- [ ] Was SBOM generated?

**Validation Process**:

```bash
# Sample 10 random PRs
gh pr list --state merged --limit 100 --json number | \
  jq -r '.[].number' | shuf -n 10 > sampled-prs.txt

# Check each PR
while read pr; do
  echo "Checking PR #$pr"
  gh pr view $pr --json reviews,commits | \
    jq '{
      pr: '$pr',
      reviews: [.reviews[] | select(.state == "APPROVED") | .author.login],
      signed: [.commits[] | .commit.signature]
    }'
done < sampled-prs.txt
```

---

### Week 3: Gap Analysis

!!! warning "Gaps Are Normal on First Run"
    Every organization has gaps on the first mock audit. The goal isn't perfection. The goal is knowing what's missing before auditors ask.

Identify gaps:

- [ ] Missing evidence for specific time periods?
- [ ] Repos without branch protection?
- [ ] Releases without SLSA provenance?
- [ ] Scorecard checks failing?

**Gap Detection**:

```bash
# Find repos without branch protection
gh repo list org --limit 1000 --json name --jq '.[].name' | while read repo; do
  gh api repos/org/$repo/branches/main/protection >/dev/null 2>&1 || echo "Missing: $repo"
done

# Find releases without provenance
gh release list --limit 50 | while read release; do
  VERSION=$(echo $release | awk '{print $1}')
  gh release view $VERSION --json assets | \
    jq '.assets[].name' | grep -q intoto || echo "Missing provenance: $VERSION"
done
```

---

### Week 4: Remediation

Fix all gaps before real audit.

**Remediation Checklist**:

- [ ] Deploy branch protection to missing repos
- [ ] Backfill missing evidence archives
- [ ] Generate SLSA provenance for recent releases
- [ ] Address Scorecard check failures
- [ ] Document exceptions and waivers

---

## Continuous Improvement

### Monthly Review

- Run compliance report generation
- Review OpenSSF Scorecard for score drops
- Verify evidence collection completed successfully
- Check for new repositories without protection

### Quarterly Audit Simulation

- Request historical evidence
- Sample PRs for review compliance
- Verify SLSA provenance on releases
- Test evidence retrieval speed

### Annual Certification

- Renew OpenSSF Best Practices Badge
- Review and update compliance report template
- Update evidence retention policies
- Schedule external audit

---

## Related Patterns

- **[Audit Evidence](phase-4-audit-evidence.md)** - Evidence collection
- **[Compliance Validation](phase-4-compliance.md)** - Scorecard and verification
- **[Phase 4 Overview →](phase-4-advanced.md)** - Advanced phase summary

---

*Mock audit complete. Gaps identified. Remediation finished. Real audit readiness verified.*
