---
description: >-
  Remediation playbooks for Branch-Protection and Dependency-Update-Tool
  checks with GitHub settings and Renovate/Dependabot configuration.
tags:
  - scorecard
  - branch-protection
  - dependencies
---

# Branch Protection & Dependency Management Checks

!!! tip "Key Insight"
    Branch protection ensures code quality through mandatory reviews and status checks.

Configuration checks that enforce development workflows and dependency hygiene. These prevent accidental breakage and ensure dependencies stay current.

**Covered checks:**

- **Branch-Protection**: Enforce review requirements and prevent force pushes
- **Dependency-Update-Tool**: Automated dependency updates via Renovate or Dependabot

**Weight**: High for both. These checks prevent common security and stability issues.

---

## Branch-Protection

**Target**: 10/10 by requiring approvals, status checks, and up-to-date branches

**What it checks**: Branch protection rules on the default branch (usually `main` or `master`).

**Why it matters**: Branch protection prevents force pushes that could introduce vulnerabilities, requires code review, and ensures changes pass CI before merge. Required for compliance frameworks and prevents accidental `git push --force` disasters.

### Understanding the Score

Scorecard analyzes default branch protection settings via GitHub API.

**Scoring**:

- 10/10: All protection requirements met (reviews, status checks, up-to-date, no force push, no deletions)
- 8/10: Most requirements met, minor gaps (e.g., missing "require up-to-date")
- 5/10: Basic protection (reviews required) but missing other safeguards
- 3/10: Minimal protection, force pushes allowed or no status checks
- 0/10: No branch protection configured

**Required settings for 10/10**:

1. ✓ Require pull request reviews (at least 1 approval)
2. ✓ Require status checks to pass
3. ✓ Require branches to be up to date before merging
4. ✓ Include administrators in restrictions
5. ✗ Do not allow force pushes
6. ✗ Do not allow deletions

### Before: No Branch Protection

```bash
# GitHub Settings > Branches shows no protection rules

# Any developer can:

$ git push -f origin main  # Force push destroys history
$ git push origin :main     # Delete branch entirely
```

**Risks**:

- Force push overwrites production code with unreviewed changes
- Accidental deletion destroys entire branch history
- Commits bypass review and testing
- Non-compliant with SOC 2, ISO 27001, and other frameworks

### After: Full Branch Protection

**Settings > Branches > Add rule** for `main`:

```text
✓ Require a pull request before merging
  ✓ Require approvals: 1
  ✓ Dismiss stale pull request approvals when new commits are pushed
  ✓ Require review from Code Owners (if CODEOWNERS file exists)

✓ Require status checks to pass before merging
  ✓ Require branches to be up to date before merging
  Status checks that are required:
    ✓ test
    ✓ lint

✓ Require conversation resolution before merging

✓ Do not allow bypassing the above settings
  ✓ Include administrators

✗ Allow force pushes: Nobody
✗ Allow deletions: Nobody
```

**Protection achieved**:

- Every change requires PR with approval
- CI must pass (test, lint) before merge
- Branch must be up to date with main (no merge conflicts)
- Force pushes blocked for everyone including admins
- Branch deletion prevented

### Branch Protection via GitHub UI

**Navigate to**: Repository → Settings → Branches → Add branch protection rule

**Branch name pattern**: `main` (or your default branch)

#### Step 1: Require Pull Requests

```text
✓ Require a pull request before merging
  Required approvals: 1 (minimum for 10/10)

  Optional improvements:
  - Increase to 2+ approvals for critical repositories
  - Dismiss stale approvals when new commits are pushed (recommended)
  - Require review from Code Owners (if you have CODEOWNERS)
  - Restrict who can dismiss pull request reviews
```

**Why**: Prevents direct commits to protected branch. All code must be reviewed.

#### Step 2: Require Status Checks

```text
✓ Require status checks to pass before merging
  ✓ Require branches to be up to date before merging

  Search for status checks to require:
  - test
  - lint
  - security-scan
  - scorecard
```

**Why**: Ensures CI passes and branch is current with main before merge. Prevents merging stale code with conflicts.

**Critical**: Must enable "Require branches to be up to date before merging" for 10/10. This forces developers to merge main into their PR branch before merging, preventing integration issues.

#### Step 3: Additional Safeguards

```text
✓ Require conversation resolution before merging
  (All PR comments must be resolved)

✓ Require signed commits
  (Optional but recommended for provenance)

✓ Require linear history
  (Optional: forces rebase or squash merge)

✓ Do not allow bypassing the above settings
  ✓ Include administrators
```

**Why**: Prevents anyone, including admins, from bypassing protections. Critical for compliance and audit trails.

#### Step 4: Prevent Destructive Actions

```text
Allow force pushes: Nobody
Allow deletions: Nobody
```

**Why**: Force pushes rewrite history and can hide malicious changes. Branch deletion is catastrophic for production branches.
