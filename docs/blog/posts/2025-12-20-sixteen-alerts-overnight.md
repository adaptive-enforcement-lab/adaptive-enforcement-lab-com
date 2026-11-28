---
title: "Sixteen Alerts Overnight: When Permissions Look Fine"
date: 2025-12-20
authors:
  - mark
categories:
  - DevSecOps
  - Open Source
  - Supply Chain Security
description: >-
  16 Token-Permissions alerts appeared overnight. The workflows looked fine. The problem was invisible.
slug: sixteen-alerts-overnight
provenance: human
---
# Sixteen Alerts Overnight: When Permissions Look Fine

The workflows had been running for months. Cosign signing. SBOM generation. Release automation.

Everything worked.

Then OpenSSF Scorecard ran: **16 Token-Permissions alerts**.

The code scanning tab filled with warnings. All from one workflow file.

<!-- more -->

---

## The Alerts

GitHub Code Scanning showed 16 identical findings:

> **Token-Permissions**: Workflow has excessive permissions

Every job in `release.yml` flagged. Lint job. Test job. Build job. Sign job.

The workflow permissions looked reasonable:

```yaml
permissions:
  contents: write  # Need to upload releases
  id-token: write  # Need OIDC for Cosign
```

Those permissions made sense. Releases need write access. Cosign needs OIDC tokens.

What was wrong?

---

## The Invisible Problem

The lint job didn't upload releases. It ran `golangci-lint`.

The test job didn't need OIDC tokens. It ran `go test`.

But they both had `contents: write` and `id-token: write` because permissions were defined at **workflow level**, not **job level**.

Every job inherited maximum permissions. Even jobs that didn't need them.

Both permissions sat at the top of `release.yml`. The `lint` job, which only runs `golangci-lint run`, inherited write access and OIDC like every other job.

Scorecard's principle: grant minimum permissions per job, not maximum permissions per workflow.

---

## The Fix

Move permissions from workflow level to job level.

Set `permissions: {}` at workflow level. Give each job only its own: `contents: read` for `lint`, `contents: write` and `id-token: write` for `sign-releases`.
The [Scorecard compliance guide](../../secure/scorecard/scorecard-compliance.md) has the workflow.

One commit. 16 alerts → 0 alerts.

---

## The Source Archive Gap

Scorecard checks every asset in a release. This includes not just the ones we upload, but all of them.

GitHub auto-generates source archives for every release:

- `Source code (zip)`
- `Source code (tar.gz)`

These appear automatically. We didn't create them. We didn't sign them.

Scorecard flagged unsigned assets.

The fix required downloading GitHub's generated archives, signing them, and re-uploading.

Download the release's `.tar.gz` source archive from GitHub, sign it with `cosign sign-blob --bundle`, and upload the signature with `gh release upload`.
The [Scorecard compliance guide](../../secure/scorecard/scorecard-compliance.md) has the script.

Now every asset was signed.

---

## The Version Tag Exception

Scorecard's Pinned-Dependencies check wants actions pinned to SHA digests.

Scorecard wants `uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4`.

But some actions **require** version tags.

`ossf/scorecard-action` has internal workflow verification that fails with SHA pins. `slsa-framework/slsa-github-generator` requires version tags for `slsa-verifier` to validate builder identity.

These exceptions had to be documented explicitly in Renovate config with clear reasoning.

Not all security advice applies universally. Some tools have valid reasons to break the rules.

---

## The Settings vs Code Divide

Not all Scorecard findings are fixable with workflow changes.

Branch-Protection findings require repository settings:

```text
- Warn: required approving review count is 1 on branch 'main'
- Warn: 'last push approval' is disabled on branch 'main'
```

These need GitHub admin access, not code changes:

1. Settings → Branches → Branch protection rules
2. Increase required approvals to 2+
3. Enable "Require approval of the most recent reviewable push"

Some compliance requires coordination with repository admins. Not everything is workflow automation.

---

## The Score Progression

| Check | Before | After |
| ----- | ------ | ----- |
| Token-Permissions | 16 alerts | 0 alerts |
| Signed-Releases | 8/10 | 10/10 |
| Pinned-Dependencies | Warnings | Clean |
| Branch-Protection | 5/10 | 8/10 |

The Token-Permissions fix was code. The Signed-Releases fix was SLSA provenance. The Branch-Protection fix was repository settings.

Different problems, different solutions.

---

## What Changed

**Before**: "Permissions look reasonable for the workflow as a whole."

**After**: "Permissions must be scoped to minimum per job."

The principle of least privilege applies at job level, not workflow level.

16 alerts disappeared when we applied permissions where they mattered: at the narrowest scope.

!!! tip "Implementation Guide"
    See [OpenSSF Scorecard Compliance](../../secure/scorecard/scorecard-compliance.md) for job-level permission patterns, source archive signing, and exception documentation.

---

## Related Patterns

- **[The Score That Wouldn't Move](2025-12-18-scorecard-stuck-at-eight.md)** - SLSA provenance moves Signed-Releases from 8 to 10
- **[OpenSSF Best Practices Badge](2025-12-17-openssf-badge-two-hours.md)** - Scorecard validates what the badge certifies
- **[SDLC Hardening](2025-12-12-harden-sdlc-before-audit.md)** - Supply chain security in audit context

---

*Sixteen alerts appeared. The workflows looked fine. The problem was invisible: permissions scoped too broadly. Job-level scoping cleared the alerts. Least privilege works at the narrowest scope.*
