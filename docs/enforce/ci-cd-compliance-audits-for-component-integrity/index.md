---
title: CI/CD Compliance Audits for Component Integrity
description: >-
  Automate component identity and release process checks in CI/CD to catch
  supply chain violations before deployment.
---

Compliance audits belong in the pipeline, not in a spreadsheet reviewed after release. A CI job that verifies signatures, diffs SBOMs, and checks provenance attestations blocks a non-compliant artifact before it ships. A quarterly manual review only tells you it already shipped.

This article covers component-identity and release-process audits: proving a specific artifact is what it claims to be, at the moment it moves through the pipeline.

The broader discipline of collecting and reporting evidence across an entire SDLC (branch protection configs, workflow logs, approval records) is covered in [Audit & Compliance](../audit-compliance/audit-evidence.md).

!!! warning "False Sense of Security from Incomplete Audits"
    A compliance step that checks one attribute (say, a signature) but ignores others (SBOM drift, provenance) still lets non-compliant releases through. Partial coverage looks like a control on a dashboard and behaves like no control at all.

## Defining Component Identity Standards

Component identity standards are verifiable attributes checked automatically for every library, module, and dependency:

* **Source Provenance:** the component's origin resolves to an approved repository or trusted source.
* **Version Control:** the version matches an approved scheme; unapproved or end-of-life versions are rejected.
* **Cryptographic Signatures:** the artifact carries a valid signature confirming authenticity and integrity.
* **License Compliance:** the declared license matches organizational policy.

### Verifying Cryptographic Signatures with Cosign

A signature check in CI rejects any image that wasn't signed by the expected identity, before it reaches a deployment step:

```bash
# Verify container image signature against a keyless (OIDC) identity
cosign verify \
  --certificate-identity="https://github.com/org/repo/.github/workflows/release.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  registry.example.com/org/app:1.4.2
```

```yaml
# .github/workflows/release.yml
- name: Verify image signature
  run: |
    cosign verify \
      --certificate-identity-regexp="^https://github.com/${{ github.repository }}/" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
      "${IMAGE_REF}"
```

A non-zero exit from `cosign verify` fails the job. No manual sign-off step to forget, no exception to grant.

### Catching Dependency Drift with an SBOM Diff

Signature checks confirm the artifact is authentic; they don't confirm what's inside it changed. Diff the current SBOM against the last approved one to catch dependency additions that skipped review:

```bash
# Generate SBOM for the current build and diff against the last release
syft packages dir:. -o cyclonedx-json > sbom-current.json

sbom-diff --old sbom-approved.json --new sbom-current.json \
  --fail-on-added --fail-on-license-change > sbom-diff-report.json

if [ "$(jq '.violations | length' sbom-diff-report.json)" -gt 0 ]; then
  echo "SBOM drift detected: new or reclassified components require review"
  exit 1
fi
```

Fail the build on unreviewed additions or license changes, and require a human approval to update `sbom-approved.json` for the next baseline.

## Establishing Release Process Standards

Release process standards define the sequence of operations, approvals, and checks required before deployment:

* **Approval Gates:** mandatory human or automated approvals at critical stages, such as after security scans or before production.
* **Environment Segregation:** strict separation between development, testing, staging, and production.
* **Rollback Procedures:** defined and validated rollback strategies for every release.
* **Audit Trails:** immutable logs of every activity, change, and approval tied to a release.

### Verifying Build Provenance Before Deployment

A signed image and a clean SBOM diff still don't prove the artifact came from the expected build pipeline. Verify the SLSA provenance attestation as a gate before deployment:

```yaml
# .github/workflows/deploy.yml
- name: Verify provenance attestation
  run: |
    cosign verify-attestation \
      --type slsaprovenance \
      --certificate-identity-regexp="^https://github.com/${{ github.repository }}/" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
      "${IMAGE_REF}" \
      | jq -e '.payload | @base64d | fromjson | .predicate.builder.id | test("github.com/org/repo")'
```

If the builder identity or source repository doesn't match, the `jq` assertion fails and the deploy job stops. This closes the gap that signature verification alone leaves open: a signed artifact built from the wrong source, or by the wrong workflow, still fails the gate.

### Integrating Automated Audits into CI/CD

| Pipeline Stage          | Audit Focus                          | Example Tools/Practices                                                 |
| :---------------------- | :----------------------------------- | :---------------------------------------------------------------------- |
| **Build**               | Component identity, dependency health | Software Composition Analysis (SCA), binary attestation, package signing |
| **Test**                | Configuration, security              | Security scans, static application security testing (SAST), policy-as-code |
| **Release Orchestration** | Process adherence, artifact integrity | Workflow validation, digital signatures, immutable artifact storage      |
| **Deployment**          | Environment compliance, access control | Infrastructure as Code (IaC) scanning, runtime policy enforcement        |

### Continuous Monitoring and Reporting

A one-time audit setup goes stale. Feed the results of signature checks, SBOM diffs, and provenance verification into a dashboard that shows compliance status in real time and alerts on failures.

Keep a searchable log for forensic review. Revisit findings on a schedule and tighten both the policies and the checks that enforce them.

## Related Reading

Component-identity and release-integrity checks are one piece of a larger audit program. For evidence collection, retention, and reporting across the full SDLC:

* [Audit Evidence Collection](../audit-compliance/audit-evidence.md): what to collect, how to store it, how to retrieve it for auditors
* [Evidence Types for Audit Compliance](../audit-compliance/evidence-types.md): the six evidence categories, including SBOM archives and deployment attestations
* [Compliance Reporting](../audit-compliance/compliance-reporting.md): audit trail reconstruction and tamper-proof storage
