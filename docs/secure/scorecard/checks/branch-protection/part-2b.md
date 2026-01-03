### Option 2: Renovate (Most Flexible)

**Advantages**:

- Highly customizable
- Can auto-merge low-risk updates (GitHub Actions, patch versions)
- Groups related dependencies (e.g., all ESLint plugins in one PR)
- Faster update detection
- Better monorepo support
- Supports more ecosystems

**Disadvantages**:

- Requires third-party GitHub App installation (or self-hosted)
- More complex configuration
- Steeper learning curve

#### Basic Renovate Configuration

**Create `.github/renovate.json`**:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended"
  ],
  "schedule": [
    "before 6am on Monday"
  ]
}
```

**Scorecard**: 10/10

**What this does**:

- Extends Renovate's recommended configuration
- Runs updates once per week (Monday morning)
- Creates PR per dependency update
- Pins GitHub Actions to SHA digests automatically

#### Intermediate Renovate Configuration

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "schedule": ["before 6am on Monday"],

  "packageRules": [
    {
      "description": "Auto-pin GitHub Actions to SHA digests",
      "matchManagers": ["github-actions"],
      "pinDigests": true
    },
    {
      "description": "Exceptions that require version tags",
      "matchManagers": ["github-actions"],
      "matchPackageNames": [
        "ossf/scorecard-action",
        "slsa-framework/slsa-github-generator"
      ],
      "pinDigests": false
    },
    {
      "description": "Auto-merge patch updates for GitHub Actions",
      "matchManagers": ["github-actions"],
      "matchUpdateTypes": ["patch", "digest"],
      "automerge": true,
      "platformAutomerge": true
    }
  ]
}
```

**Improvements**:

- Auto-pins GitHub Actions to SHA (helps Pinned-Dependencies check)
- Preserves version tags for exceptions (scorecard-action, SLSA)
- Auto-merges low-risk updates when CI passes

#### Advanced Renovate Configuration

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "schedule": ["before 6am on Monday"],
  "timezone": "America/New_York",

  "prConcurrentLimit": 5,
  "prHourlyLimit": 2,

  "labels": ["dependencies"],
  "assignees": ["@platform-team"],

  "packageRules": [
    {
      "description": "Auto-pin and auto-merge GitHub Actions",
      "matchManagers": ["github-actions"],
      "pinDigests": true,
      "matchUpdateTypes": ["patch", "digest"],
      "automerge": true,
      "platformAutomerge": true
    },
    {
      "description": "Group all ESLint packages together",
      "matchPackagePatterns": ["^eslint"],
      "groupName": "eslint packages"
    },
    {
      "description": "Separate major updates for review",
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["dependencies", "major-update"],
      "reviewers": ["@security-team"]
    },
    {
      "description": "Pin container images to digests",
      "matchDatasources": ["docker"],
      "pinDigests": true
    }
  ]
}
```

**Production-ready features**:

- Rate limiting (5 concurrent PRs, 2 per hour)
- Grouped updates for related packages (reduces PR volume)
- Major updates require manual review
- Container images pinned to digests
- Team assignments and labels for triage

### Comparison: Dependabot vs Renovate

| Feature | Dependabot | Renovate |
|---------|-----------|----------|
| **Setup** | GitHub native, zero config | Requires GitHub App or self-hosted |
| **Cost** | Free | Free (GitHub App) or self-hosted |
| **Ecosystems** | 13+ (Go, npm, Docker, etc.) | 100+ (includes obscure tools) |
| **Auto-merge** | Limited (only for Dependabot-managed repos) | Full control, any package |
| **SHA Pinning** | Manual | Automatic for GitHub Actions |
| **Grouping** | Basic (groups similar deps) | Advanced (regex patterns, custom logic) |
| **Schedule** | Weekly/daily/monthly | Cron-like, highly flexible |
| **Monorepo** | Basic support | Excellent support |
| **Configuration** | YAML only | JSON with schema validation |
| **Scorecard** | 10/10 | 10/10 |

**Recommendation**:

- **Use Dependabot** if: You want simple, zero-maintenance setup and don't need auto-merge
- **Use Renovate** if: You want maximum control, auto-merge, and sophisticated grouping

### Hybrid Approach: Both Tools

**Reality**: You can run both Dependabot and Renovate simultaneously.

**Use case**:

- **Dependabot**: GitHub Actions and Docker (for native security alerts)
- **Renovate**: Everything else (for auto-merge and grouping)

**Configuration**:

`.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

`.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "ignoreDeps": [],
  "enabledManagers": ["gomod", "npm", "terraform"],
  "github-actions": {
    "enabled": false
  }
}
```

**Result**: Dependabot handles GitHub Actions (gets security alerts), Renovate handles everything else (gets auto-merge).

**Scorecard**: Still 10/10 (detects both tools).

### Troubleshooting Dependency Updates

#### Issue: Renovate/Dependabot creating too many PRs

**Symptom**: 20+ open dependency PRs clogging your repository.

**Solutions**:

**Limit concurrent PRs**:

```json
{
  "prConcurrentLimit": 5,
  "prHourlyLimit": 2
}
```

**Group related dependencies**:

```json
{
  "packageRules": [
    {
      "groupName": "GitHub Actions",
      "matchManagers": ["github-actions"]
    }
  ]
}
```

**Reduce update frequency**:

```json
{
  "schedule": ["before 6am on the first day of the month"]
}
```

#### Issue: Dependency updates break CI

**Problem**: Auto-updates introduce breaking changes, CI fails, PRs pile up.

**Solutions**:

**Separate patch/minor/major updates**:

```json
{
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": true
    },
    {
      "matchUpdateTypes": ["minor"],
      "automerge": false,
      "labels": ["review-required"]
    },
    {
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["breaking-change"],
      "reviewers": ["@senior-team"]
    }
  ]
}
```

**Pin to specific version ranges**:

```json
{
  "packageRules": [
    {
      "matchPackageNames": ["problematic-package"],
      "allowedVersions": "< 2.0.0"
    }
  ]
}
```

#### Issue: Scorecard still shows 0/10 for Dependency-Update-Tool

**Check 1**: Is the config file in the correct location?

- Dependabot: `.github/dependabot.yml` (must be in `.github/`)
- Renovate: `.github/renovate.json`, `renovate.json`, or `.renovaterc`

**Check 2**: Is the config file valid?

```bash
# Validate Dependabot config
gh api /repos/:owner/:repo/dependabot/alerts

# Validate Renovate config
npx -y -p renovate renovate-config-validator
```

**Check 3**: Has Scorecard run since adding the config?

Scorecard caches results. Wait 24 hours or manually trigger a new scan:

```bash
gh api -X POST /repos/:owner/:repo/actions/workflows/scorecard.yml/dispatches \
  -f ref=main
```

#### Issue: Renovate GitHub App not creating PRs

**Check**: Is Renovate installed for your repository?

Navigate to: [Renovate GitHub App](https://github.com/apps/renovate) → Configure → Check repository access

**Check**: Does Renovate have write permissions?

Settings → Integrations → Renovate → Permissions → Ensure "Read & write" for pull requests

**Debug**: Check Renovate logs

Navigate to: [Renovate Dashboard](https://app.renovatebot.com/dashboard) → Select repository → View logs

#### Issue: Dependabot security alerts not appearing

**Enable Dependabot alerts**:

Settings → Security → Dependabot → Enable "Dependabot alerts"

**Check**: Is your dependency file recognized?

Dependabot only supports specific ecosystems. Verify yours is supported in the [Dependabot configuration documentation](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file#package-ecosystem).

---
