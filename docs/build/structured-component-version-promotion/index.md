---
title: Structured Component Version Promotion
description: >-
  Promotion gates, immutable artifacts, and approval checkpoints for moving one component version from dev to production without drift.
---

# Structured Component Version Promotion

One artifact, one version, every environment. That is the whole rule. Skip it and you get environment drift, hotfixes that only work in staging, and production incidents nobody can reproduce because "it" was never really the same build twice.

!!! warning
    Promoting component versions without clear gates and an immutable artifact leads to environment drift, unexpected behavior, and production issues that are hard to trace back to a specific change.

## Defining Deployment Environments

A promotion strategy needs clearly scoped environments, each with a distinct job in the release lifecycle.

| Environment     | Purpose                                                             | Key Characteristics                                                   |
| :-------------- | :------------------------------------------------------------------- | :------------------------------------------------------------------- |
| **Development**   | Individual developer workstations; early-stage feature work.         | Flexible, often incomplete or unstable.                               |
| **Integration**   | Continuous integration and automated testing.                        | Mirrors production closely enough for automated validation to mean something. |
| **Staging**       | Pre-production testing, user acceptance, performance validation.     | Production-like data and scale; the last gate before real traffic.   |
| **Production**    | Live environment serving end users.                                  | Stable, secured, continuously monitored.                              |

### Version Pinning and Immutability

Every component version promoted through the environments must be immutable. Once a specific version (for example `0.1.22`) is built and tested, that exact artifact, identified by its unique tag or digest, is what deploys to every environment after that.
Configuration changes per environment; the artifact does not.

Do not trust the tag alone. Verify the digest before you promote:

```bash
# Confirm the artifact tested in staging is the exact one about to ship to production
STAGING_DIGEST=$(skopeo inspect docker://registry.example.com/component-x:0.1.22 --format '{{.Digest}}')
PROD_DIGEST=$(yq '.image.digest' environments/production/values.yaml)

if [ "$STAGING_DIGEST" != "$PROD_DIGEST" ]; then
  echo "Digest mismatch: production is about to ship a different build than the one tested in staging" >&2
  exit 1
fi
```

A tag can be overwritten. A digest cannot. Gate the promotion on the digest check, not the tag.

### Establishing Promotion Gates

Promotion gates are the checkpoints a component version must clear before it advances. Each one should be enforced by tooling, not by a checklist someone reads and forgets.

- **Automated Testing**: Unit, integration, and end-to-end tests pass with defined coverage and success thresholds.
- **Security Scans**: SAST/DAST and dependency vulnerability scans clear at the defined severity threshold.
- **Configuration Review**: Environment-specific overrides (for example in a `values.yaml` for containerized deployments) are correct and accounted for.
- **Manual Approval**: Staging and Production need a human sign-off, not just green CI.
  Enforce it with a GitHub Actions [environment protection rule](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
  or an Argo CD manual sync, so the approval is a platform control, not a step in a wiki page.

### The Promotion Process

Automate the promotion process in CI/CD so every version follows the same path.

1. **Build & Version**: Component is built, versioned (for example `0.1.22`), and the artifact is stored with a content digest.
2. **Integrate & Test**: Deployed to the Integration environment; automated tests run against it.
3. **Qualify & Certify**: Deployed to Staging; UAT, performance, and security testing run against the same artifact.
4. **Release & Monitor**: Once Staging gates pass, the same immutable artifact deploys to Production. This is typically a manifest or values-file update referencing the promoted version, landed via a commit like `chore(promote): component-x 0.1.22 -> production`.
5. **Rollback Capability**: A tested path back to the previous stable version exists before you need it, not after.

Wired into GitHub Actions, the promotion itself looks like this:

```yaml
# .github/workflows/promote.yml
name: Promote to Production

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Component version to promote (e.g. 0.1.22)"
        required: true

jobs:
  promote:
    runs-on: ubuntu-latest
    environment: production # requires reviewer approval, configured in repo settings
    steps:
      - uses: actions/checkout@v4

      - name: Confirm the version cleared the staging gate
        run: |
          gh api "repos/${{ github.repository }}/deployments?environment=staging&ref=v${{ inputs.version }}" \
            --jq '.[0].id' | xargs -I{} gh api "repos/${{ github.repository }}/deployments/{}/statuses" \
            --jq '.[0].state' | grep -q success

      - name: Bump the production image tag
        run: |
          yq -i '.image.tag = "${{ inputs.version }}"' environments/production/values.yaml

      - name: Open the promotion PR
        run: |
          git checkout -b promote/${{ inputs.version }}
          git commit -am "chore(promote): component-x ${{ inputs.version }} -> production"
          gh pr create \
            --title "Promote component-x ${{ inputs.version }} to production" \
            --body "Staging gates passed. Promoting the same immutable artifact, no rebuild."
```

The `environment: production` line is what actually enforces the manual approval. Without it, this workflow is a suggestion; with it, GitHub blocks the job until an approver signs off.

## See Also

This article covers the promotion decision process: the gates, the immutability check, and the workflow that enforces sign-off.
For the deployment mechanics that sit underneath it, including Kustomize overlays, Argo CD sync policies, load testing, and rollback
scripting, see [Environment Progression Testing](../../patterns/architecture/environment-progression.md).
