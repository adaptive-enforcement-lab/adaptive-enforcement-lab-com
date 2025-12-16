---
date: 2025-12-23
authors:
  - mark
categories:
  - Supply Chain Security
  - DevSecOps
  - Release Engineering
description: >-
  SLSA provenance generated successfully. Verification failed. Version tags contradicted security advice. The exception that had to be documented.
slug: file-wouldnt-verify
---

# The File That Wouldn't Verify: When Security Best Practices Contradict

The provenance file generated perfectly. Build completed. Release uploaded.

`slsa-verifier` failed:

```text
Error: builder identity not recognized
```

Same workflow that worked last month. Nothing changed.

Except everything changed.

<!-- more -->

---

## The Setup

SLSA Level 3 provenance generation was working:

```yaml
provenance:
  uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
  with:
    base64-subjects: ${{ needs.build.outputs.hashes }}
    upload-assets: true
```

Release assets included `multiple.intoto.jsonl`. The provenance file existed. The build was attested.

Verification should have been simple:

```bash
slsa-verifier verify-artifact readability_linux_amd64 \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/adaptive-enforcement-lab/readability
```

Expected: **PASSED: SLSA verification passed**

Actual: **Error: builder identity not recognized**

---

## The Security Practice

Every security guide says the same thing: **Pin GitHub Actions to SHA digests.**

Version tags can be moved. SHA digests are immutable.

**Standard practice**:

```yaml
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
```

**Renovate enforces it**:

```json
{
  "extends": [
    "config:recommended",
    "helpers:pinGitHubActionDigests"
  ]
}
```

This is non-negotiable security hygiene. SHA pins prevent:

- Tag hijacking
- Version rollback attacks
- Malicious code injection via tag updates

---

## The SLSA Requirement

SLSA provenance generation **requires version tags**, not SHA pins.

**This fails**:

```yaml
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@abc123def456
```

**This works**:

```yaml
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
```

Why? Because `slsa-verifier` validates the builder identity against a **list of known version tags**.

The verifier expects:

```text
"https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@refs/tags/v2.1.0"
```

Not:

```text
"https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@abc123def456"
```

SHA references fail verification. They're not in the known builder identity list.

---

## The Contradiction

Security best practice: Pin actions to SHA digests.

SLSA requirement: Use version tags for builder identity validation.

**These contradict.**

You can't have both:

- Immutable action references (SHA pins)
- SLSA Level 3 provenance verification (version tags)

One must give.

---

## The Discovery

The SLSA documentation buries this detail in examples. The error message doesn't explain it:

```text
Error: builder identity not recognized
```

It should say:

```text
Error: builder identity must use version tag (@vX.Y.Z), not SHA digest.
slsa-verifier validates against known version tags only.
```

We found the issue through:

1. Reading slsa-verifier source code
2. Comparing working vs failing workflow references
3. Testing version tag vs SHA pin explicitly

The solution was clear: **Use version tags for slsa-github-generator only.**

---

## The Exception

We documented the exception in Renovate configuration:

```json
{
  "packageRules": [
    {
      "description": "slsa-github-generator requires version tags for slsa-verifier compatibility",
      "matchPackageNames": ["slsa-framework/slsa-github-generator"],
      "pinDigests": false
    }
  ]
}
```

This prevents Renovate from converting `@v2.1.0` to SHA digests.

The exception is **documented** with **clear reasoning**:

- slsa-verifier validates builder identity against version tags
- SHA references fail verification
- Version tags are required for SLSA Level 3 compliance

---

## The Pattern

This isn't the only valid exception. Another:

**ossf/scorecard-action** requires version tags for internal workflow verification:

```json
{
  "matchFileNames": [".github/workflows/scorecard.yml"],
  "pinDigests": false
}
```

The pattern:

1. Security tools sometimes **require** version tags
2. This contradicts general SHA-pinning best practice
3. Document the exception with clear reasoning
4. Prevent automation from "fixing" it

---

## The Lesson

**Not all security advice applies universally.**

- SHA pinning is best practice **except when it isn't**
- SLSA requires version tags **for valid reasons**
- Document exceptions **explicitly**
- Understand **why** tools have requirements

Security isn't about dogmatic rule-following. Understand trade-offs. Document exceptions.

The file wouldn't verify. We followed best practices. We didn't understand the tool's constraints.

!!! tip "Implementation Guide"
    See [SLSA Provenance Implementation](../../enforce/supply-chain/slsa-provenance.md) for complete workflow code, version tag requirements, and Renovate exception documentation.

---

## Related Patterns

- **[The Score That Wouldn't Move](2025-12-18-scorecard-stuck-at-eight.md)** - SLSA provenance moves Signed-Releases from 8 to 10
- **[Sixteen Alerts Overnight](2025-12-20-sixteen-alerts-overnight.md)** - OpenSSF Scorecard exceptions
- **[SDLC Hardening](2025-12-12-harden-sdlc-before-audit.md)** - Supply chain security in audit context

---

*Provenance generated. Verification failed. SHA pins contradicted version tag requirements. Exception documented. Trade-offs understood. Security isn't dogma. It's informed decisions.*
