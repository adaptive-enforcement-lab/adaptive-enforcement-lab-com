# Branch Protection via Terraform

!!! tip "Key Insight"
    Terraform-managed branch protection provides consistent, auditable enforcement across repositories.

## Branch Protection via Terraform

Infrastructure-as-code approach for managing multiple repositories:

```hcl
resource "github_branch_protection" "main" {
  repository_id = github_repository.repo.node_id
  pattern       = "main"

  # Require pull request reviews
  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    required_approving_review_count = 1
    restrict_dismissals             = true
    dismissal_restrictions = [
      data.github_user.admin.node_id,
    ]
  }

  # Require status checks
  required_status_checks {
    strict   = true  # CRITICAL: Require up-to-date branches
    contexts = [
      "test",
      "lint",
      "security-scan",
    ]
  }

  # Additional protections
  enforce_admins                  = true
  require_conversation_resolution = true
  require_signed_commits          = false  # Optional
  required_linear_history         = false  # Optional

  # Prevent destructive actions
  allows_deletions    = false
  allows_force_pushes = false
}
```

**Key parameter for 10/10**: `strict = true` in `required_status_checks` block. This is equivalent to "Require branches to be up to date before merging" in the UI.

### Repository Rulesets (Modern Alternative)

GitHub's newer Repository Rulesets provide more flexible configuration and better organization-level enforcement:

**Navigate to**: Settings → Rules → Rulesets → New ruleset → New branch ruleset

#### Ruleset Configuration

```yaml
# Ruleset: Main Branch Protection

Enforcement status: Active
Bypass list: (empty for maximum protection)

Target branches:
  Include default branch: ✓

Rules:
  Restrict creations: ✗
  Restrict updates: ✓ (see below)
  Restrict deletions: ✓

  Require a pull request before merging:
    Required approvals: 1
    Dismiss stale pull request approvals when new commits are pushed: ✓
    Require review from Code Owners: ✓
    Require approval of the most recent reviewable push: ✓
    Require conversation resolution before merging: ✓

  Require status checks to pass:
    Required status checks:
      - test
      - lint
      - security-scan
    Require branches to be up to date before merging: ✓

  Block force pushes: ✓
```

**Advantages over classic branch protection**:

1. **Organization-level rulesets**: Apply same rules across all repositories
2. **Multiple rulesets per branch**: Layer different protections
3. **Better bypass control**: Granular exceptions for specific teams/users
4. **Import/export**: Easier to replicate across repositories
5. **Future-proof**: GitHub's recommended approach going forward

#### Creating Organization-Level Ruleset

For enforcing protection across all repositories:

**Navigate to**: Organization → Settings → Repository → Rulesets → New ruleset

```yaml
# Organization Ruleset: Default Branch Protection

Enforcement status: Active

Target repositories:
  ✓ All repositories

Target branches:
  Include default branch: ✓

Rules: (same as above)
```

**Use case**: Security/platform teams can enforce minimum protection standards. Individual repositories can layer additional restrictions via repository-level rulesets.

### Enterprise vs Non-Enterprise Differences

#### GitHub Enterprise Features

**Enhanced branch protection** (Enterprise Cloud/Server only):

```text
Additional settings available:

✓ Restrict who can push to matching branches
  Select users/teams allowed to push

✓ Require deployments to succeed before merging
  Select deployment environments that must succeed

✓ Lock branch (read-only mode)
  Prevents all changes, even from admins
```

**Code scanning integration**:

```text
✓ Require Code Scanning results
  Block merge if vulnerabilities detected
```

**Push restrictions**:

- Non-Enterprise: Anyone with write access can push to branch (unless protected)
- Enterprise: Can restrict push access to specific users/teams even on unprotected branches

#### Achieving 10/10 Without Enterprise

All settings required for Branch-Protection 10/10 are available in **GitHub Free**:

- ✓ Require pull request reviews
- ✓ Require status checks with up-to-date branches
- ✓ Block force pushes and deletions
- ✓ Include administrators

**Enterprise is not required** for perfect Scorecard score.

#### When Enterprise Features Matter

**Use Enterprise if you need**:

1. **Push restrictions**: Limit who can push to specific branches beyond branch protection
2. **Deployment gates**: Require successful deployment to staging before production merge
3. **Code scanning blocking**: Prevent merge if security vulnerabilities detected
4. **SAML SSO**: Required for compliance in some organizations
5. **Advanced auditing**: Detailed audit logs for compliance frameworks

### Common Branch Protection Patterns

#### Pattern 1: Standard Protection (Most Projects)

```text
Approvals: 1
Status checks: test, lint
Up to date: Yes
Force push: Blocked
Admins included: Yes
```

**Scorecard**: 10/10

**Use case**: Most open source and internal projects.

#### Pattern 2: Critical Systems (High Security)

```text
Approvals: 2
Dismiss stale reviews: Yes
Code Owner review: Required
Status checks: test, lint, security-scan, penetration-test
Up to date: Yes
Force push: Blocked
Deletions: Blocked
Signed commits: Required
Admins included: Yes
```

**Scorecard**: 10/10

**Use case**: Production infrastructure, security-critical code, compliance-heavy environments.

#### Pattern 3: Solo Developer (Realistic Protection)

```text
Approvals: 0 (not possible to self-approve)
Status checks: test, lint
Up to date: Yes
Force push: Blocked
Admins included: Yes
```

**Scorecard**: 6/10 to 8/10

**Reality**: Solo developers can't achieve 10/10 without adding another contributor or using a bot reviewer.

**Workaround**: Some use GitHub Apps as reviewers, but this is controversial and may be considered gaming the system.

#### Pattern 4: Fast-Moving Startups (Pragmatic Balance)

```text
Approvals: 1
Status checks: test
Up to date: No (allow quick merges)
Force push: Allowed for admins only
Admins included: No
```

**Scorecard**: 5/10 to 7/10

**Trade-off**: Velocity over perfect compliance. Acceptable during rapid prototyping phase. Tighten before raising funding or going to production.

### Troubleshooting Branch Protection

#### Issue: Status checks not appearing in "Require status checks" list

**Cause**: GitHub only shows status checks that have run at least once.

**Solution**:

1. Create a PR with a workflow that reports the status check
2. Wait for workflow to complete
3. Return to branch protection settings. The check should now appear

**Example workflow to establish check**:

```yaml
name: Test
on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Test check established"
```

#### Issue: "Require branches to be up to date" is unchecked

**Impact**: Scorecard will score this 8/10 instead of 10/10.

**Why it matters**: Without this, PRs can be merged with stale code that conflicts with recent main changes, causing integration issues.

**Solution**: Check the box. Yes, it means developers must click "Update branch" before merging. This is intentional friction that prevents bugs.

#### Issue: Administrators bypass protection

**Problem**: Even with branch protection enabled, admins can push directly.

**Scorecard impact**: Will score lower if "Include administrators" is not checked.

**Solution**: Enable "Do not allow bypassing the above settings" → "Include administrators"

**Emergency bypass**: If you need to override protection in a true emergency:

1. Temporarily disable "Include administrators"
2. Make emergency fix
3. Re-enable "Include administrators"
4. Document the incident in post-mortem

#### Issue: Can't enable "Require branches to be up to date" because status checks fail

**Symptom**: Enabling "Require branches to be up to date" causes all PRs to fail because workflows don't run on PR branches.

**Root cause**: Workflows configured with `on: push` instead of `on: pull_request`.

**Solution**: Update workflows to run on both:

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

#### Issue: Third-party apps can't merge PRs

**Symptom**: Renovate, Dependabot, or other bots can't merge their own PRs even though auto-merge is configured.

**Cause**: Branch protection requires human approver.

**Solutions**:

**Option 1**: Use GitHub auto-merge (recommended)

```yaml
# .github/renovate.json

{
  "automerge": true,
  "automergeType": "pr",
  "platformAutomerge": true
}
```

Renovate creates PR → GitHub auto-merge waits for status checks → Merges when checks pass. Still requires human approval first.

**Option 2**: Approve bot PRs automatically with GitHub Actions

```yaml
name: Auto-approve Renovate
on: pull_request

jobs:
  auto-approve:
    if: github.actor == 'renovate[bot]'
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - uses: hmarr/auto-approve-action@v3
```

**Security consideration**: Only auto-approve dependency update bots, never arbitrary PRs.

#### Issue: Scorecard still shows Branch-Protection as 8/10

**Check**: Are you protecting the **default branch**?

Scorecard only checks the default branch (shown on repo homepage). Protection rules on other branches don't count.

**Verify**:

```bash
# Check default branch

gh repo view --json defaultBranchRef --jq .defaultBranchRef.name

# Check protection on that branch

gh api repos/:owner/:repo/branches/main/protection
```

**Solution**: Ensure protection rule matches your default branch name exactly.

---
