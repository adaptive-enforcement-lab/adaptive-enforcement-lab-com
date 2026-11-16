---
title: "The Score That Wouldn't Move: Stuck at 8/10"
date: 2025-12-18
authors:
  - mark
categories:
  - DevSecOps
  - Supply Chain Security
  - Open Source
description: >-
  Stuck at 8/10 on OpenSSF Scorecard with signed releases? Learn how SLSA provenance
  bridges the gap to achieve a perfect 10/10.
slug: scorecard-stuck-at-eight
---
# The Score That Wouldn't Move: Stuck at 8/10

The releases were signed. Checksums published. SBOM generated. Every asset had a Cosign signature.

OpenSSF Scorecard: **Signed-Releases 8/10**.

Not 9. Not 10. Eight. Stuck.

<!-- more -->

---

## The Documentation Said We Were Done

Every security guide said the same thing:

- ✅ Sign your releases with Cosign
- ✅ Generate checksums
- ✅ Include SBOM
- ✅ Use HTTPS for distribution

We had all of it. Release assets looked like this: a tar.gz archive, a Cosign signature file
(`.sig`), an SBOM file (`.cdx.json`), and a checksums file (`.txt`).

The Scorecard documentation was clear: "Score 8: Cryptographic signatures present."

We had signatures. We had 8. Why not 10?

---

## The Gap Between Signed and Proven

Cosign signatures prove an artifact hasn't been tampered with **after** it was built.

They don't prove:

- What source code produced it
- What build environment was used
- Whether the build was isolated
- Who triggered the build

A signature says "this file is what I released." It doesn't say "this file came from a trusted
build process."

There's a critical gap between signed and **provably built**. That's exactly what SLSA Level 3 fills.

---

## The SLSA Discovery

Scorecard's documentation buried the key detail:

> **Score 10**: SLSA provenance present (`.intoto.jsonl` files)

Not more signatures. Not better signatures. **Build provenance**.

SLSA Level 3 provenance captures build metadata signed by GitHub's identity provider.
The attestation proves:

- Exact source commit
- Isolated GitHub-hosted runner
- Workflow that triggered the build
- OIDC token from GitHub (not developer)

The attestation is cryptographically bound to the artifacts. Change a byte, verification fails.
Claim a different commit, verification fails.

---

## The Implementation Struggle

The `slsa-github-generator` workflow had one non-negotiable constraint: version tags, not SHA pins.
While standard security practice dictates pinning actions to SHA digests
(e.g., `uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4`),
`slsa-github-generator` requires version tags
(e.g., `uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0`).
This is because `slsa-verifier` validates the builder identity against **known version tags**,
causing SHA references to fail verification. This contradicts standard practice, requiring
documentation of the exception in Renovate config with clear reasoning.

---

## The Hash Format Mystery

The generator needed hashes in base64-encoded format, not hex or raw SHA256. After three
iterations, it was discovered that using `sha256sum readability_* | base64 -w0 > hashes.txt`
produced the accepted base64-encoded format. The documentation mentioned this, but it was
buried in examples, making trial and error necessary.

---

## The Victory

Release v1.7.1 included a new file: `multiple.intoto.jsonl`.

Verification involved using `slsa-verifier verify-artifact readability_linux_amd64
--provenance-path multiple.intoto.jsonl --source-uri github.com/adaptive-enforcement-lab/readability`,
which resulted in an output confirming successful SLSA verification, including the builder and
commit details.

Next Scorecard run: **Signed-Releases 10/10**.

The score moved. Not because of more signatures. Because of **provenance**.

---

## What Changed

**Before**: "This file is what I released and it hasn't been tampered with."

**After**: "This file was built from commit `15dab4a` by GitHub's infrastructure using workflow
`release.yml` and the build was isolated and tamper-evident."

Signatures prove distribution integrity. Provenance proves build integrity.

Both matter. Scorecard knows the difference.

---

## The Broader Pattern

This gap appears everywhere in security:

- Documentation vs Enforcement
- Intent vs Proof
- Signatures vs Attestations

We moved from "we signed our releases" to "our builds are cryptographically provable."

The jump from 8 to 10 wasn't about doing more. It was about proving more.

!!! tip "Implementation Guide"
    See [SLSA Provenance Implementation](../../enforce/slsa-provenance/slsa-provenance.md)
    for workflow code, hash generation patterns, and verification commands.

---

## Related Patterns

- **[OpenSSF Best Practices Badge](2025-12-17-openssf-badge-two-hours.md)** - The foundation
  that made SLSA implementation straightforward
- **[SDLC Hardening](2025-12-12-harden-sdlc-before-audit.md)** - Supply chain defense in audit context

---

*The score was stuck. Signatures weren't enough. Provenance moved the needle. From 8 to 10.
From signed to proven.*
