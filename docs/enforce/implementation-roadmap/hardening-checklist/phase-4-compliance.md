---
description: >-
  Compliance validation for SDLC hardening. OpenSSF Scorecard monitoring, Best Practices Badge, SLSA verification, dependency compliance, and automated report generation.
tags:
  - compliance
  - openssf
  - slsa
  - scorecard
  - validation
---

# Phase 4: Compliance Validation

Prove to auditors that controls are real, not cosmetic.

---

## OpenSSF Scorecard

### Monthly Score Tracking

- [ ] **Run OpenSSF Scorecard monthly and track score**

  ```bash
  #!/bin/bash
  # scripts/run-scorecard.sh

  for repo in $(gh repo list org --limit 1000 --json name --jq '.[].name'); do
    docker run -v /tmp:/tmp \
      gcr.io/openssf/scorecard-action:stable \
      --repo=github.com/org/$repo \
      --format=json \
      > /tmp/$repo-scorecard.json

    SCORE=$(jq '.score' /tmp/$repo-scorecard.json)
    echo "$repo: $SCORE/10"
  done

  ```

  **How to validate**:

  ```bash
  docker run -v /tmp:/tmp \
    gcr.io/openssf/scorecard-action:stable \
    --repo=github.com/org/repo \
    --format=json | jq '.checks[] | select(.score < 10) | {name, score, reason}'
  # Should show areas for improvement
  ```

  **Why it matters**: Scorecard rates your SDLC controls. 10/10 means you have provenance, signatures, code review, and all the hard controls. Auditors recognize this score.

!!! example "Scorecard Check Breakdown"
    - **Branch-Protection**: Are admins enforced? Required reviews?
    - **Code-Review**: Do PRs have approvals?
    - **Signed-Releases**: Are releases signed with Sigstore?
    - **SAST**: Do you run static analysis?
    - **Pinned-Dependencies**: Are actions pinned to SHA?

---

## Best Practices Badge Verification

### OpenSSF Certification

- [ ] **Obtain and display OpenSSF Best Practices Badge**

  Go to [bestpractices.coreinfrastructure.org](https://bestpractices.coreinfrastructure.org) and:

  1. Click "Get Badge"
  2. Answer questionnaire (25-30 questions about your SDLC)
  3. Receive badge and assertion document
  4. Add to README: `[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/XXXXX/badge)](https://bestpractices.coreinfrastructure.org/projects/XXXXX)`

  **How to validate**:

  ```bash
  curl https://bestpractices.coreinfrastructure.org/projects/XXXXX.json | \
    jq '{badge_level: .badge_level, passing: .passing_level_percent}'
  # Should show: PASSING and 100%

  ```

  **Why it matters**: Badge proves third-party verification of your practices. Auditors recognize the badge requirement.

---

## SLSA Level Verification

### Build Provenance Validation

- [ ] **Verify SLSA Level 3 compliance**

  ```bash
  # For each release:
  gh release view vX.Y.Z --json assets | jq -r '.assets[].name'
  # Should include: app.tar.gz.intoto.jsonl

  slsa-verifier verify-artifact app.tar.gz \
    --provenance-path app.tar.gz.intoto.jsonl \
    --source-uri github.com/org/repo
  # Should output: Verified SLSA provenance
  ```

  **How to validate**:

  ```bash
  # Verify last 3 releases
  gh release list | head -3 | while read line; do
    VERSION=$(echo $line | awk '{print $1}')
    gh release view $VERSION --json assets | jq '.assets[].name' | grep intoto
  done
  # Should find .intoto.jsonl for each release
  ```

  **Why it matters**: SLSA Level 3 is non-negotiable for regulated industries. Auditors will verify provenance on sampled releases.

---

## Dependency Compliance Check

### License Validation

- [ ] **Verify no GPL or problematic licenses in dependencies**

  ```bash
  #!/bin/bash
  # scripts/check-licenses.sh

  # For Go projects
  go-licenses report ./... | grep -i gpl
  # Should return empty

  # For Node projects
  npm audit --audit-level=moderate
  # Should return clean (exit 0)

  ```

  **How to validate**:

  ```bash
  # Generate SBOM and check licenses
  syft . -o json | jq '.artifacts[] | select(.licenses[].value | contains("GPL")) | .name'
  # Should return empty
  ```

  **Why it matters**: GPL in proprietary code creates legal liability. Auditors verify dependency licenses in SBOMs.

---

## Compliance Report Generation

### Monthly Automated Reports

- [ ] **Create monthly compliance report for auditor handoff**

  ```bash
  #!/bin/bash
  # scripts/generate-compliance-report.sh

  REPORT="compliance-report-$(date +%Y-%m).md"

  cat > $REPORT <<EOF
  # SDLC Compliance Report - $(date +%B %Y)

  ## Branch Protection
  $(gh api repos/org/repo/branches/main/protection | jq -r '.enforce_admins.enabled' && echo "✅ Enforced for admins")

  ## Commit Signatures
  Coverage: $(./scripts/calculate-signature-coverage.sh $(date +%Y-%m-01) $(date +%Y-%m-31) | grep -oP '\d+(?=%)')%

  ## SBOM Generation
  Artifacts generated: $(gsutil ls gs://audit-evidence/sbom/$(date +%Y-%m)/ | wc -l)

  ## OpenSSF Scorecard
  Latest score: $(curl -s https://api.scorecards.dev/projects/github.com/org/repo | jq '.score')

  ## Pre-commit Hook Distribution
  Deployed to: $(gsutil ls gs://audit-evidence/ | wc -l) repositories
  EOF

  echo "Report generated: $REPORT"

  ```

  **How to validate**:

  ```bash
  ./scripts/generate-compliance-report.sh
  cat compliance-report-*.md
  # Should show clear compliance status
  ```

  **Why it matters**: Auditors need one document that summarizes your controls. Generate it before they ask.

!!! success "Compliance Report Template"
    Include: Branch protection status, signature coverage, SBOM count, Scorecard score, policy violations, remediation timeline, and next audit date.

---

## Metrics to Track

**Evidence Coverage**:

- Percentage of repositories with archived branch protection
- Percentage of PRs with review records
- Commit signature coverage percentage
- SBOM generation rate
- SLSA provenance coverage

**Compliance Posture**:

- OpenSSF Scorecard score trend
- OpenSSF Best Practices Badge status
- Dependency license compliance rate
- Policy violation rate

**Audit Readiness**:

- Time to retrieve evidence
- Evidence completeness percentage
- Gap remediation time

!!! success "Target Metrics"
    - Evidence coverage: 100% of repositories
    - Signature coverage: 100% of commits
    - Scorecard score: ≥ 8.0/10
    - Evidence retrieval time: < 10 minutes
    - Gap remediation: < 7 days

---

## Common Issues and Solutions

**Issue**: Scorecard score drops unexpectedly

**Solution**: Monitor Scorecard with alerting:

```bash
SCORE=$(curl -s https://api.scorecards.dev/projects/github.com/org/repo | jq '.score')
if (( $(echo "$SCORE < 8.0" | bc -l) )); then
  echo "ALERT: Scorecard score dropped to $SCORE" | mail -s "Scorecard Alert" team@company.com
fi
```

**Issue**: Compliance reports don't match auditor expectations

**Solution**: Review previous audit reports and align report format to auditor requirements. Include all metrics they requested last time.

---

## Related Patterns

- **[Audit Evidence](phase-4-audit-evidence.md)** - Evidence collection automation
- **[Audit Simulation](phase-4-audit-simulation.md)** - Mock audit process
- **[Phase 4 Overview →](phase-4-advanced.md)** - Advanced phase summary

---

*Scorecard monitored. SLSA verified. Licenses compliant. Reports automated. Compliance is continuous.*
