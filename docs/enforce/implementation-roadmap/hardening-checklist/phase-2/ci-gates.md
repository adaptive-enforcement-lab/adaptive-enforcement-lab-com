---
title: Phase 2: CI/CD Gates
description: >-
  CI/CD gates for SDLC hardening. Required status checks, test validation, security scanning, SBOM generation, and SLSA provenance to prevent failing builds from merging.
tags:
  - ci-cd
  - github-actions
  - testing
  - security-scanning
  - sbom
---
# Phase 2: CI/CD Gates

Make security and quality checks mandatory before any merge.

---

## Required Status Checks Workflow

### Core CI Pipeline

- [ ] **Create required-checks workflow that validates all merges**

  ```yaml
  # .github/workflows/required-checks.yml
  name: Required Checks
  on: [pull_request]

  permissions:
    contents: read
    security-events: write

  jobs:
    tests:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: actions/setup-go@v4
          with:
            go-version: '1.21'
        - run: go test -race ./...

    lint:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: golangci/golangci-lint-action@v3

    security-scan:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Run security scan
          run: |
            go install github.com/securego/gosec/v2/cmd/gosec@latest
            gosec ./...

  ```

  **How to validate**:

  ```bash
  # Create failing test in PR
  echo "func TestFail(t *testing.T) { t.Fatal() }" >> main_test.go
  git add main_test.go && git commit -m "test"
  git push origin feature-branch
  # GitHub Actions should show test failure, blocking merge
  ```

  **Why it matters**: Tests that fail, code with vulnerabilities, and lint violations never merge.

!!! tip "Required vs Optional Checks"
    Make security scans **required** status checks. Make performance benchmarks **optional**. Don't block merges on flaky metrics, but always block on security failures.

---

## SBOM Generation

### Software Bill of Materials

- [ ] **Generate and store SBOM for every build**

  ```yaml
  - name: Generate SBOM
    uses: anchore/sbom-action@v0
    with:
      image: ${{ secrets.REGISTRY }}/app:${{ github.sha }}
      format: cyclonedx-json
      output-file: sbom.json

  - name: Upload SBOM to evidence storage
    run: |
      gsutil cp sbom.json gs://audit-evidence/sbom/$(date +%Y-%m-%d)/${{ github.run_id }}.json

  ```

  **How to validate**:

  ```bash
  # Retrieve SBOM for last build
  gsutil cp gs://audit-evidence/sbom/$(date +%Y-%m-%d)/* .
  # Verify dependencies are listed
  jq '.components | length' sbom.json  # Should be > 0
  ```

  **Why it matters**: Software Bill of Materials proves what dependencies are in production. Required for supply chain audits (SLSA, OpenSSF Scorecard).

!!! example "SBOM Use Case: Log4Shell Response"
    When Log4Shell was announced, teams with SBOMs identified affected services in minutes. Teams without SBOMs spent days grepping codebases and guessing at transitive dependencies.

---

## Vulnerability Scanning

### Container Image Scanning

- [ ] **Scan container images for vulnerabilities**

  ```yaml
  - name: Build and scan image
    run: |
      crane append -t app:${{ github.sha }} .
      trivy image --severity HIGH,CRITICAL --exit-code 1 \
        app:${{ github.sha }}

  ```

  **How to validate**:

  ```bash
  # Build and scan locally
  crane append -t app:test .
  trivy image --severity HIGH,CRITICAL app:test
  # Should return 0 (no vulnerabilities)
  ```

  **Why it matters**: HIGH and CRITICAL vulnerabilities in production are unacceptable. Scanning in CI prevents deployment.

---

## SLSA Provenance

### Build Attestation

- [ ] **Generate SLSA Level 3 provenance for releases**

  ```yaml
  # .github/workflows/release.yml
  permissions: {}

  jobs:
    build:
      permissions:
        contents: read
      runs-on: ubuntu-latest
      outputs:
        hashes: ${{ steps.hash.outputs.hashes }}
      steps:
        - uses: actions/checkout@v4
        - run: go build -o app .
        - name: Generate hashes
          id: hash
          run: |
            sha256sum app | base64 -w0 > hashes.txt
            echo "hashes=$(cat hashes.txt)" >> $GITHUB_OUTPUT

    provenance:
      needs: build
      permissions:
        id-token: write
        contents: write
      uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3@v2.1.0
      with:
        base64-subjects: ${{ needs.build.outputs.hashes }}
        upload-assets: true

  ```

  **How to validate**:

  ```bash
  # Verify .intoto.jsonl exists in release
  gh release view vX.Y.Z --json assets | jq '.assets[].name' | grep intoto

  # Verify signature
  slsa-verifier verify-artifact app.tar.gz \
    --provenance-path app.tar.gz.intoto.jsonl
  ```

  **Why it matters**: Proves build integrity from source commit to artifact. Required for OpenSSF Scorecard Level 10.

!!! warning "SLSA Provenance and Forks"
    SLSA provenance generation requires write access to releases. If using a forked repository, use the reusable workflow approach with GitHub Actions OIDC tokens.

---

## Evidence Collection

### Automated Archival

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

**Issue**: CI workflows time out or are too slow

**Solution**: Parallelize jobs and use caching:

```yaml
jobs:
  tests:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        test-suite: [unit, integration, e2e]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: ~/.cache/go-build
          key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
      - run: go test -run ${{ matrix.test-suite }} ./...
```

**Issue**: Vulnerability scanner flags false positives

**Solution**: Use a suppression file for documented exceptions:

```yaml
# .trivyignore
CVE-2024-1234 # Used in test environment only, not production
CVE-2024-5678 # Mitigated by network policy, patch breaks compatibility
```

**Issue**: SLSA provenance generation fails on forks

**Solution**: Use OIDC token authentication instead of GitHub token:

```yaml
permissions:
  id-token: write  # Required for OIDC token
  contents: write  # Required to upload assets
```

---

## Related Patterns

- **[Evidence Collection](evidence-collection.md)** - Automated archival details
- **[Phase 2 Overview →](index.md)** - Automation phase summary
- **[Phase 3: Runtime →](../phase-3/index.md)** - Production policy enforcement

---

*CI gates deployed. Tests required. Security scans mandatory. SBOM generated. SLSA provenance signed.*
