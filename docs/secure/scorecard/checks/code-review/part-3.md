# Repository Maintenance

!!! tip "Key Insight"
    Repository activity metrics help identify abandoned or unmaintained projects.

## Maintained

**Target**: 10/10 by committing regularly

**What it checks**: Whether repository shows signs of active maintenance.

**Why it matters**: Abandoned projects accumulate security vulnerabilities and don't receive dependency updates.

### Understanding the Score

Scorecard analyzes:

- Commit activity in last 90 days
- Issue and PR activity
- Release frequency

**Scoring**:

- 10/10: Commits within last 7 days
- 7/10: Commits within last 30 days
- 5/10: Commits within last 90 days
- 0/10: No activity in 90+ days

**Important**: This measures activity, not abandonment intent.

### Active Development Pattern

**Regular commits** from ongoing development:

```bash
$ git log --oneline --since="90 days ago" | wc -l
47
```

**Recent releases**:

```bash
$ gh release list --limit 5
v2.1.0  Latest  2025-01-01
v2.0.1  Patch   2024-12-15
v2.0.0  Major   2024-12-01
```

**Issue triage**:

```bash
# Issues closed in last 30 days

$ gh issue list --state closed --search "closed:>2024-12-01" | wc -l
12
```

**Result**: Maintained 10/10. Active development is visible.

### Stable Project Pattern

**Problem**: Mature, stable project with infrequent changes.

**Example**: Library reached feature-complete state, only needs occasional dependency updates.

**Reality**: Low commit frequency doesn't mean abandoned.

**Signals of maintained-but-stable**:

1. **Recent issue responses** (even if no code changes):

   ```markdown
   # Issue #123 opened yesterday
   Maintainer: "This is expected behavior. See documentation at ..."
   ```

2. **Dependency updates** via Renovate:

   ```yaml
   # Even stable projects get dependency updates
   - Merge pull request #45 from renovate/update-deps
   ```

3. **Security patches** applied promptly:

   ```bash
   # CVE-2024-1234 published Jan 1
   # Dependency updated Jan 2
   git log --oneline --since="2025-01-01"
   a1b2c3d Update vulnerable dependency
   ```

### Keep-Alive Commits (Controversial)

**The pattern**:

```bash
# Automated monthly commit to show activity

echo "$(date)" > .last-update
git add .last-update
git commit -m "Update timestamp"
git push
```

**Scorecard result**: Maintained 10/10

**Ethical considerations**:

- **Against**: Artificial activity that doesn't reflect real maintenance
- **For**: Signals "I'm still watching this project" to users
- **Compromise**: Only use if you're actually monitoring issues and security advisories

**Better approach**: Enable Renovate for automatic dependency updates. Real maintenance, visible activity.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "schedule": ["every weekend"]
}
```

**Result**: Regular dependency update PRs demonstrate active maintenance without artificial commits.

### Archived Projects

If project is intentionally archived:

**GitHub archive feature**:

```text
Settings → Archive this repository
```

**Result**:

- Scorecard score drops to 0
- Repository shows "ARCHIVED" banner
- Issues and PRs disabled

**When to archive**:

- Project superseded by newer version
- Functionality merged into another project
- No longer maintained and no active users

**When NOT to archive**:

- Stable but still used in production
- Security issues still being monitored
- Dependency updates still being applied

### Troubleshooting

#### Project is maintained but score is 0

**Check**: When was last commit?

```bash
git log -1 --format="%ci"
```

**Solution**: If > 90 days, make a legitimate update:

- Apply dependency updates
- Fix documentation typos
- Update README with current status
- Add security policy

**Avoid**: Empty commits with no value.

#### All maintenance happens in private fork

**Cause**: Organization maintains private fork, syncs to public occasionally.

**Pattern**: This breaks Scorecard's activity detection.

**Solutions**:

1. Make primary development public
2. Sync more frequently (weekly instead of quarterly)
3. Document maintenance status in README:

   ```markdown
   # Maintenance Status

   Active development occurs in private fork.
   Public repository receives quarterly releases.

   Last sync: 2025-01-01
   Next sync: 2025-04-01
   ```

#### Project is stable, not abandoned, but looks unmaintained

**Accept lower score**: Maintained check reflects activity, not value.

**Mitigate**:

1. Enable Renovate for automated dependency updates
2. Respond to issues quickly (even if no code changes needed)
3. Add "Maintenance Status" section to README:

   ```markdown
   # Maintenance Status

   This project is feature-complete and stable.

   - Issues are monitored and responded to within 48 hours
   - Security updates are applied within 24 hours of disclosure
   - Dependencies are kept current via Renovate

   Low commit frequency is intentional, not abandonment.
   ```

---

## Remediation Priority

**Order of implementation** for fastest improvement:

1. **Code-Review** (1 to 2 hours): Enable branch protection requiring approvals
2. **Maintained** (0 to 1 hour): Enable Renovate for automated updates
3. **Contributors** (N/A): Organic growth over time, cannot be forced

**Total estimated effort**: 1 to 3 hours for immediate fixes.

**Long-term**: Contributors grow naturally through project visibility and contribution quality.

---

## Check Interactions

**Code-Review + Branch-Protection**:

Both checks require GitHub branch protection settings. Fixing one often fixes the other.

**Code-Review + Dangerous-Workflow**:

Required reviews catch dangerous workflow patterns before merge. Defense in depth.

**Maintained + Dependency-Update-Tool**:

Renovate provides regular dependency updates, which count as maintenance activity.

**Contributors + Code-Review**:

Multiple contributors require code review infrastructure. Review process makes contribution easier.

**Maintained + Vulnerabilities**:

Active maintenance correlates with faster vulnerability remediation.

---

## Related Content

**Existing guides**:

- [Scorecard Index](../index.md): Overview of all 18 checks
- [Branch Protection Checks](./branch-protection.md): Detailed branch protection configuration
- [Supply Chain Checks](./supply-chain.md): Pinned-Dependencies and Token-Permissions
- [Tier 1 Progression](../score-progression/tier-1.md): Quick wins including branch protection

**Related patterns**:

- [GitHub Apps](../../github-apps/index.md): Bot accounts for automation without admin access

---

## Next Steps

1. **Enable branch protection**: Settings → Branches → Add rule for main branch

2. **Require reviews**: Minimum 1 approval, dismiss stale reviews

3. **Create CODEOWNERS**: Define reviewers for security-sensitive paths

4. **Enable Renovate**: Automated dependency updates count as maintenance

5. **Monitor compliance**: Add Scorecard to CI to prevent regressions

**Quick validation**:

```bash
# Check current Code-Review score

docker run -e GITHUB_TOKEN=$GITHUB_TOKEN gcr.io/openssf/scorecard:stable \
  --repo=github.com/your-org/your-repo \
  --checks=Code-Review,Contributors,Maintained
```

**Remember**: Code-Review is high-weight security control. Contributors and Maintained are health signals. Prioritize review requirements first.

---

*Code review is the last line of defense against bugs and security issues. Enforce it everywhere.*
