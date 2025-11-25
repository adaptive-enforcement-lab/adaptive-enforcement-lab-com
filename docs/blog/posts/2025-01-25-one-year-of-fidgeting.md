---
date: 2025-01-25
authors:
  - mark
categories:
  - DevSecOps
  - GitHub Actions
  - Automation
slug: one-year-of-fidgeting-with-github-app-automation
---

# One Year of Fidgeting: The Journey to Enterprise-Grade Content Distribution

Today marks a milestone. The Adaptive Enforcement Lab documentation site is live, and with it, a year's worth of battle-tested patterns for GitHub App automation finally have a proper home.

This wasn't a sprint. It was an on-and-off effort spanning twelve months, guided by a simple principle: one building block at a time.
Atomic habits applied to infrastructure.
Some weeks meant solving a single authentication edge case. Others meant no progress at all.
The pieces accumulated slowly, each one small enough to ship, test, and trust before moving on.

Then came today. A marathon session to wire everything together.
The discovery stage that had been working in isolation.
The distribution logic refined over months of incremental improvements.
The idempotency patterns born from countless failed reruns.
Today was assembly day—taking a year of atomic improvements and building the complete content distribution system.

This post covers that journey from "let's automate some file syncing" to "we need enterprise-grade security for 40 repositories."

<!-- more -->

## The Problem That Started It All

It began with a simple request: keep CONTRIBUTING.md synchronized across all team repositories. How hard could it be?

The naive approach was a scheduled workflow with a personal access token. It worked. For about three weeks. Then:

- The token expired
- Someone rotated it without updating the secret
- Rate limits hit during a large sync
- Audit complained about a human account making automated commits

Classic.

## Attempt One: Fine-Grained PATs

GitHub's fine-grained personal access tokens seemed promising. Scoped permissions, expiration dates, repository targeting. Better than the classic PAT.

Problems emerged quickly:

- Still tied to a human identity
- Expiration meant manual rotation
- No audit trail distinguishing human vs. automated actions
- 40 repositories meant 40 installation targets to manage

We needed machine identity. Enter GitHub Apps.

## The GitHub App Learning Curve

Creating the first GitHub App took 20 minutes. Making it actually work took six months.

### The Authentication Dance

The first hurdle: GitHub Apps don't use static tokens. They use JWTs signed with a private key, exchanged for short-lived installation tokens. Every. Single. Request.

```yaml
# What we thought we needed
env:
  GITHUB_TOKEN: ${{ secrets.APP_TOKEN }}

# What we actually needed
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    owner: our-org
```

That `owner` parameter? Crucial. Without it, the token scopes to the current repository only. We burned two weeks on that one.

### Permission Minimalism

The security team wanted least privilege. Fair. But GitHub App permissions are coarse-grained at the repository level and fine-grained at the API level.

We needed:

- Read team membership (to discover target repos)
- Read/write contents (to push files)
- Read/write pull requests (to create PRs)

What we accidentally granted first:

- Full admin access

The permission audit was not a fun meeting.

### The Discovery Problem

With 40 repositories, hardcoding targets wasn't sustainable. Teams spin up new repos. Old ones get archived. The sync list was always stale.

Solution: GraphQL queries against team membership.

```graphql
{
  organization(login: "our-org") {
    team(slug: "platform-team") {
      repositories(first: 100) {
        nodes {
          name
          defaultBranchRef { name }
        }
      }
    }
  }
}
```

Now the workflow discovers targets dynamically. New repo joins the team? Automatically included in next sync.

## The Matrix Strategy Revelation

Distributing to 40 repos sequentially took 45 minutes. Unacceptable for a workflow that might need re-runs.

GitHub Actions matrix strategy changed everything:

```yaml
strategy:
  matrix:
    repo: ${{ fromJson(needs.discover.outputs.repositories) }}
  fail-fast: false
  max-parallel: 10
```

Key insights:

- `fail-fast: false` prevents one repo failure from aborting the entire run
- `max-parallel: 10` respects rate limits while maintaining speed
- Dynamic matrix from discovery output keeps everything in sync

45 minutes became 8.

## The Idempotency Requirement

Workflows fail. Networks hiccup. Reruns happen.

Early versions created duplicate PRs, merge conflicts, and branch chaos. The security team was not amused by commit history that looked like a toddler mashed the keyboard.

Requirements crystallized:

1. Branch operations must be idempotent
2. PRs must update, not duplicate
3. No-change runs must be silent

The branch preparation script became critical:

```bash
if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
  git checkout -B "$BRANCH" "origin/$BRANCH"  # Force reset
else
  git checkout -b "$BRANCH"
fi
```

That `-B` flag. Tiny detail. Massive impact. It force-resets the branch to remote state, eliminating drift.

## Troubleshooting Hall of Fame

A year of production use surfaced patterns worth documenting:

### "Resource not accessible by integration"

Translation: the app lacks a required permission. Usually `members:read` for org queries or `contents:write` for pushes.

### "Bad credentials" on token generation

The private key has a newline issue. GitHub's PEM format is picky. Base64 encoding during storage helps, but decode carefully.

### Discovery returns zero repositories

Three possibilities:

1. Team slug is wrong
2. App not installed on the org
3. Missing `owner` parameter in token generation

We hit all three. Sometimes in the same debugging session.

### PRs created but workflows don't trigger

GitHub's security model prevents `GITHUB_TOKEN` from triggering workflows to avoid infinite loops. The GitHub App token bypasses this. Except when it doesn't.

Check: is the app authorized for the `workflows` permission? Is `workflow_dispatch` in the trigger? Are branch protection rules blocking?

## Today's Launch

The documentation site represents the distillation of this journey. Every troubleshooting section exists because we lived it. Every permission recommendation comes from audit findings. Every security practice emerged from a near-miss or actual incident.

The file distribution pattern now runs weekly across 40 repositories:

- Discovery via GraphQL team membership
- Parallel distribution with matrix strategy
- Idempotent branch and PR management
- Summary job with clickable PR links

Total runtime: under 10 minutes. Zero manual intervention required.

## What's Next

The operator manual covers GitHub App setup, but that's just the foundation. Coming soon:

- Policy-as-code enforcement patterns
- Automated security scanning integration
- Cross-repository dependency management
- Audit log aggregation and alerting

The mission remains: turn secure development into an enforced standard, not an afterthought.

Every pattern documented here works in production. Every recommendation has been tested against real enterprise requirements. No theoretical frameworks. No "it should work" handwaving.

Just automation that survives contact with reality.

---

*Questions? Feedback? Open an issue on [GitHub](https://github.com/adaptive-enforcement-lab/adaptive-enforcement-lab-com).*
