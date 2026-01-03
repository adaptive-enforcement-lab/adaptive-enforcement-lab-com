---
description: >-
  Remediation playbooks for code review checks including Code-Review,
  Contributors, and Maintained with GitHub branch protection patterns.
tags:
  - scorecard
  - code-review
  - quality
---

# Code Review & Project Health Checks

!!! tip "Key Insight"
    Code reviews prevent security vulnerabilities and maintain code quality standards.

Checks that measure code review practices and project health signals. These ensure human oversight of code changes and demonstrate active maintenance.

**Covered checks:**

- **Code-Review**: Human review before merge
- **Contributors**: Community diversity and contribution patterns
- **Maintained**: Active development signals

**Weight**: High for Code-Review, Low for Contributors and Maintained

---

## Code-Review

**Target**: 10/10 by requiring approvals on all PRs

**What it checks**: Whether pull requests receive human review before merge.

**Why it matters**: Human review catches security issues, logic errors, and code quality problems that automated tools miss. Required for compliance frameworks like SOC 2 and ISO 27001.

### Understanding the Score

Scorecard analyzes:

- Percentage of recent commits that went through PR review
- GitHub branch protection settings requiring reviews
- Commit history patterns showing direct pushes vs. PR merges

**Scoring**:

- 10/10: All commits in last 30 days have PR review approval
- 7/10: Most commits reviewed, occasional direct pushes
- 3/10: Some commits reviewed, many direct pushes
- 0/10: No evidence of code review

### Before: Direct Pushes Allowed

```yaml
# .github/settings.yml or branch protection UI

# No branch protection configured

```

**Commit history shows**:

```bash
$ git log --oneline -10
a1b2c3d Fix typo (committed directly to main)
d4e5f6g Update dependencies (committed directly to main)
g7h8i9j Add feature (committed directly to main)
```

**Risk**: Bugs, security vulnerabilities, and breaking changes can reach production without review.

### After: Required Reviews with Branch Protection

```yaml
# Settings > Branches > Branch protection rules for 'main'

Required settings:
✓ Require a pull request before merging
  ✓ Require approvals: 1
  ✓ Dismiss stale pull request approvals when new commits are pushed
✓ Require status checks to pass before merging
✓ Do not allow bypassing the above settings
```

**Commit history shows**:

```bash
$ git log --oneline -10
a1b2c3d Merge pull request #123 from user/fix-typo
d4e5f6g Merge pull request #122 from user/update-deps
g7h8i9j Merge pull request #121 from user/add-feature
```

**Protection**: Every change reviewed by at least one person other than the author.

### Branch Protection via GitHub UI

**Navigate to**: Settings → Branches → Add rule

**Rule for**: `main` (or your default branch)

**Required settings for Code-Review 10/10**:

1. ✓ **Require a pull request before merging**
   - Require approvals: 1 (minimum)
   - Dismiss stale approvals when new commits are pushed (recommended)
   - Require review from Code Owners (if you have CODEOWNERS file)

2. ✓ **Require status checks to pass before merging**
   - Require branches to be up to date before merging

3. ✓ **Do not allow bypassing the above settings**
   - Include administrators

4. ✗ **Do NOT check "Allow force pushes"**
5. ✗ **Do NOT check "Allow deletions"**

### Branch Protection via Terraform

For infrastructure-as-code management:

```hcl
resource "github_branch_protection" "main" {
  repository_id = github_repository.repo.node_id
  pattern       = "main"

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    required_approving_review_count = 1
  }

  required_status_checks {
    strict = true
    contexts = [
      "test",
      "lint",
    ]
  }

  enforce_admins = true

  allows_deletions    = false
  allows_force_pushes = false
}
```

### Repository Rulesets (New Approach)

GitHub's newer Repository Rulesets provide more flexible configuration:

**Navigate to**: Settings → Rules → Rulesets → New ruleset → New branch ruleset

**Ruleset configuration**:

```yaml
# Enforcement: Active

# Target: Default branch

Rules:
  - Require a pull request before merging
    Required approvals: 1
    Dismiss stale approvals: enabled
  - Require status checks to pass
    Required checks: test, lint
    Require branches to be up to date: enabled
  - Block force pushes
  - Restrict deletions
```

**Advantages over branch protection**:

- Multiple rulesets can target the same branch
- More granular control over who rules apply to
- Better inheritance for organization-level policies

### CODEOWNERS for Targeted Review

Create `.github/CODEOWNERS` to require specific reviewers for sensitive paths:

```text
# Default: require review from any team member

* @org/developers

# Security-sensitive: require security team review

/security/          @org/security-team
/auth/              @org/security-team
/.github/workflows/ @org/security-team

# Infrastructure: require platform team review

/terraform/         @org/platform-team
/k8s/               @org/platform-team

# Specific files: require specific expertise

package.json        @org/dependencies-team
Dockerfile          @org/platform-team
```

**Result**: Pull requests automatically request review from code owners. Branch protection can require code owner approval.

### Exception: Emergency Fixes

**Reality**: Sometimes you need to bypass review for critical production fixes.

**Safe pattern**:

1. Configure branch protection to allow admin bypass:

   ```text
   ✓ Do not allow bypassing the above settings
   ✗ Include administrators  # Unchecked allows admin override
   ```

2. Document emergency procedure:

   ```markdown
   # Emergency Fix Procedure

   1. Only use for SEV-1 production outages
   2. Requires VP Engineering approval in Slack
   3. Create tracking issue immediately
   4. Create follow-up PR within 24h for retroactive review
   5. Document decision in incident post-mortem
   ```

3. Monitor bypasses:

   ```bash
   # Audit log query for bypass events
   gh api /repos/org/repo/events --paginate | \
     jq '.[] | select(.type == "PushEvent") | select(.payload.ref == "refs/heads/main")'
   ```

**Trade-off**: Security vs. availability. Document when bypasses are justified.

### Troubleshooting

#### Score still low despite branch protection enabled

**Check**: Are commits merged via PR or pushed directly?

```bash
# Count PR merges vs direct commits in last 30 days

git log --since="30 days ago" --oneline | \
  grep -c "Merge pull request"
```

**Cause**: Scorecard analyzes actual commit patterns, not just settings.

**Solution**: Ensure all contributors use PR workflow. No direct pushes to main.

#### Administrator commits bypass branch protection

**Check**: Is "Include administrators" enabled in branch protection?

**Solution**: Enable "Include administrators" to enforce rules on all users.

**Alternative**: Use GitHub Apps for automation instead of admin users. Apps can have write access without being admins.

#### Need to allow automated commits without PR

**Pattern**: Use a bot account or GitHub App that creates PRs, not direct commits.

```yaml
# Renovate example - creates PRs, doesn't push directly

- name: Renovate
  uses: renovatebot/github-action@v40.1.11
  # Creates PRs that require review
```

**Avoid**:

```yaml
# BAD: Bot pushes directly to main

- run: |
    git config user.name "bot"
    git commit -am "Update dependencies"
    git push
```

#### Scorecard doesn't detect reviews from GitHub Enterprise

**Known issue**: Some enterprise configurations don't expose review data to API.

**Workaround**: Document review process in repository README. Scorecard limitation acknowledged by OpenSSF.

---
