# Tier 3 Additional Priorities

!!! tip "Key Insight"
    Vulnerability automation and contributor diversity strengthen long-term security.

## Priority 4: Vulnerabilities (Ongoing)

**Target**: Vulnerabilities 10/10

**Fix**: Active monitoring and patching of known CVEs in dependencies.

This is **not a one-time fix**. It's ongoing maintenance.

### Automated Scanning

Integrate Trivy for comprehensive vulnerability scanning:

```yaml
name: Vulnerabilities

on:
  push:
    branches: [main]
  pull_request:
  schedule:

    - cron: '0 0 * * 1'  # Weekly

jobs:
  scan:
    permissions:
      contents: read
      security-events: write
    runs-on: ubuntu-latest
    steps:

      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: aquasecurity/trivy-action@master

        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - uses: github/codeql-action/upload-sarif@v3

        with:
          sarif_file: 'trivy-results.sarif'

```bash
### Process for Handling Vulnerabilities

**1. Review alerts** (Weekly minimum):

- Check Dependabot/Renovate PRs
- Review GitHub Security tab
- Monitor Trivy scan results

**2. Triage findings**:

- **Critical/High**: Address immediately
- **Medium**: Fix in next sprint
- **Low**: Evaluate and schedule
- **False positives**: Document and suppress

**3. Update dependencies**:

```bash
# For Go

go get -u ./...
go mod tidy

# For npm

npm audit fix

# For Python

pip-audit --fix

```bash
**4. For unfixable CVEs**:

- Document risk acceptance
- Implement compensating controls
- Monitor for patches
- Consider alternative dependencies

**5. Verify fixes**:

- Run scans after updates
- Ensure no new vulnerabilities introduced
- Test application functionality

### Monitoring Schedule

**Weekly**:

- Review new vulnerability alerts
- Merge security patch PRs

**Monthly**:

- Comprehensive dependency audit
- Review suppressed findings (still valid?)

**Quarterly**:

- Evaluate dependency alternatives
- Update scanning tools

**Impact**: Ongoing maintenance. Keeps dependencies secure. Required for sustained 10/10 score.

---

## Priority 5: Contributors and Maintained (Not Directly Controllable)

**Target**: Contributors 10/10, Maintained 10/10

**Context**: These checks measure project health, not security controls you implement.

### Contributors

**What it measures**: Diversity of committers (different people, different organizations).

**Score factors**:

- Number of unique contributors
- Distribution of commits across contributors
- Recent contributor activity

**What you can't control**:

- Solo-maintained projects inherently score lower
- Small teams have limited contributor diversity

**Action**: Accept the score. Focus on real security controls, not gaming contributor counts.

### Maintained

**What it measures**: Recent activity signals active maintenance.

**Score factors**:

- Recent commits (last 90 days)
- Issue activity (opened, closed, commented)
- Release frequency

**What you can control**:

- Keep project active with regular commits
- Respond to issues promptly
- Release updates regularly (even small ones)

**Action**: Active projects score well naturally. Don't create fake activity just for score.

**Impact**: Minimal. These checks are informational, not actionable security controls.

---

## Maintenance: Keeping Your 10/10 Score

Achieving 10/10 is not the end. Scorecard checks evolve. Dependencies update. New CVEs emerge.

### Ongoing Tasks

**Weekly**:

- ✅ Review Dependabot/Renovate PRs
- ✅ Monitor new Scorecard findings (if automated)
- ✅ Triage new vulnerability alerts
- ✅ Merge security patches

**Monthly**:

- ✅ Run Scorecard manually (verify automation working)
- ✅ Review branch protection settings (still enforced?)
- ✅ Check for new CVEs in dependencies
- ✅ Audit token permissions in new workflows

**Quarterly**:

- ✅ Update SLSA generator to latest version
- ✅ Review and update SECURITY.md
- ✅ Verify CII badge criteria still met
- ✅ Evaluate new Scorecard checks (if added)

### Automated Monitoring

Set up weekly Scorecard runs:

```yaml
name: Scorecard

on:
  schedule:

    - cron: '0 0 * * 1'  # Weekly on Monday at midnight UTC

permissions:
  security-events: write
  id-token: write
  contents: read

jobs:
  scorecard:
    runs-on: ubuntu-latest
    steps:

      - uses: ossf/scorecard-action@v2.4.0

        with:
          results_file: results.sarif
          results_format: sarif
          publish_results: true

      - uses: github/codeql-action/upload-sarif@v3

        with:
          sarif_file: results.sarif

```bash
**Benefits**:

- Automated weekly Scorecard runs
- Results uploaded to Code Scanning tab
- Alerts on score regressions
- Tracks changes over time

**Impact**: Continuous monitoring. Catches regressions before they compound. Maintains 10/10 score.

**Details**: [CI/CD Integration guide](../ci-integration.md) *(Coming soon)*

---

## Checkpoint: Score 9 → 10

After selective improvements:

- ✅ CII Best Practices badge earned (community certification)
- ✅ Fuzzing implemented (if applicable to project type)
- ✅ Perfect branch protection (if team size supports it)
- ✅ Vulnerabilities actively monitored and patched
- ✅ Automated monitoring set up
- ✅ Documented exceptions for non-applicable checks

**Expected Scorecard improvements**:

| Check | Before | After |
| ----- | ------ | ----- |
| CII-Best-Practices | 0/10 | 10/10 |
| Fuzzing | 0/10 | 0 or 10/10 (selective) |
| Branch-Protection | 9/10 | 9 or 10/10 (selective) |
| Vulnerabilities | Variable | 10/10 (with ongoing maintenance) |

**Result**: Exceptional security posture. Continuous monitoring and maintenance. Not all projects reach 10/10 on every check, and that's okay.

---

## Troubleshooting

### "CII badge questionnaire is overwhelming"

**Tip**: You likely already meet most criteria. Link to existing proof (CI, SECURITY.md, etc.).

**Fast-track**: [Badge in 2 Hours](../../../blog/posts/2025-12-17-openssf-badge-two-hours.md)

### "Fuzzing finds too many issues"

**Triage**: Separate crashes (fix) from slow inputs (lower priority).

**Adjust**: Start with shorter fuzz times, increase gradually.

**Consider**: Maybe your code has real issues that need fixing.

### "Signed commits breaking CI"

**Fix**: Configure GPG signing for GitHub Actions bot.

**Alternative**: Exempt CI commits from signing requirement.

### "Vulnerabilities score keeps dropping"

**Expected**: New CVEs are published constantly.

**Action**: This is why it's ongoing maintenance, not a one-time fix.

**Process**: Weekly review and patching cycle.

---

## Related Content

- **[Score Progression Overview](../score-progression.md)** - Full roadmap from 7 to 10
- **[Tier 1 Guide](tier-1.md)** - Quick wins: Token-Permissions, Security-Policy, etc.
- **[Tier 2 Guide](tier-2.md)** - Advanced security: SLSA provenance, SHA pinning
- **[OpenSSF Badge in 2 Hours](../../../blog/posts/2025-12-17-openssf-badge-two-hours.md)** - Fast-track CII certification
- **[Scorecard Compliance](../scorecard-compliance.md)** - Detailed compliance patterns

---

## Final Thoughts on 10/10

**Not all projects should aim for 10/10 on every check.**

The Scorecard score measures best practices. Best practices should be evaluated in context:

- **Fuzzing**: Essential for parsers and crypto. Overkill for CRUD apps.
- **Perfect branch protection**: Critical for large teams. Impractical for solo maintainers.
- **CII badge**: Shows commitment to security. Quick win for projects already following best practices.

**What matters**:

- Fix real security gaps (Tier 1 and 2)
- Document justified exceptions (Tier 3)
- Maintain what you implement (Ongoing)

**10/10 is exceptional, not required.** Most projects should aim for 9/10 with documented exceptions for non-applicable checks.

**Remember**: The score measures security practices. Don't game the number. Fix real gaps. Build secure systems.

---

*Exceptional security achieved. Community certification earned. Continuous monitoring in place. Maintain it. Don't chase perfect scores. Build secure systems.*
