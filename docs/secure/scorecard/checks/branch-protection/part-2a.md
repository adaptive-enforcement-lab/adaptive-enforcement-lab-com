## Dependency-Update-Tool

**Target**: 10/10 by enabling Dependabot or Renovate

**What it checks**: Presence of automated dependency update configuration (Dependabot, Renovate, or similar tools).

**Why it matters**: Dependencies with known vulnerabilities pile up fast. Automated updates catch security patches early and reduce manual toil. Prevents the "dependency debt" that makes security fixes expensive.

### Understanding the Score

Scorecard looks for:

- `.github/dependabot.yml` (GitHub Dependabot)
- `.github/renovate.json`, `renovate.json`, `.renovaterc` (Renovate)
- `.pyup.yml` (PyUp for Python)
- Other dependency update tool configurations

**Scoring**:

- 10/10: Dependency update tool configured and active
- 0/10: No dependency update tool found

**Binary score**: Either you have automated updates (10) or you don't (0).

### Before: Manual Dependency Updates

**Package.json from 6 months ago**:

```json
{
  "dependencies": {
    "express": "^4.17.1",  // Current: 4.19.2 (security fixes)
    "axios": "^0.21.1"      // Current: 1.6.5 (critical CVE)
  }
}
```

**Result**:

- Security vulnerabilities accumulate
- Manual updates become overwhelming
- Developers avoid updating due to breaking changes
- Technical debt compounds

### After: Automated Updates with Renovate

**Create `.github/renovate.json`**:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "schedule": ["before 6am on Monday"],
  "packageRules": [
    {
      "description": "Auto-merge patch and minor updates for low-risk packages",
      "matchUpdateTypes": ["patch", "minor"],
      "matchPackageNames": ["actions/*"],
      "automerge": true,
      "platformAutomerge": true
    }
  ]
}
```

**Result**:

- Renovate creates PRs for each dependency update
- CI runs tests automatically
- Low-risk updates auto-merge if tests pass
- Major updates require manual review
- Dependencies stay current

**Scorecard**: 10/10

### Option 1: GitHub Dependabot (Native)

**Advantages**:

- Built into GitHub, no third-party access required
- Zero configuration to enable basic functionality
- Native GitHub security alerts integration
- Free for all repositories (public and private)

**Limitations**:

- Less flexible than Renovate (no auto-merge for third-party actions)
- Slower update cycle
- Limited customization options
- Can't group related dependencies in single PR

#### Basic Dependabot Configuration

**Create `.github/dependabot.yml`**:

```yaml
version: 2
updates:
  # GitHub Actions dependencies
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  # Go modules
  - package-ecosystem: "gomod"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  # npm dependencies
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      # Group development dependencies together
      development:
        patterns:
          - "@types/*"
          - "eslint*"
          - "prettier"
```

**Scorecard**: 10/10 immediately after adding this file.

#### Advanced Dependabot Configuration

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "03:00"
      timezone: "America/New_York"

    # Limit PR volume
    open-pull-requests-limit: 10

    # Add labels for filtering
    labels:
      - "dependencies"
      - "github-actions"

    # Require approval before merge
    reviewers:
      - "platform-team"

    # Assign to specific team
    assignees:
      - "security-team"

    # Customize commit messages
    commit-message:
      prefix: "chore"
      include: "scope"

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    # Pin digests for container images
    insecure-external-code-execution: deny
```

**Result**: Controlled, predictable dependency updates with team accountability.
