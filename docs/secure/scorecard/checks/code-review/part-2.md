## Contributors

**Target**: 5+/10 by encouraging diverse contributions

**What it checks**: Number of different contributors making code changes.

**Why it matters**: Multiple contributors reduce single-point-of-failure risk. Projects with diverse contributors are more likely to survive maintainer burnout.

### Understanding the Score

Scorecard analyzes:

- Number of unique contributors in recent history
- Distribution of contributions (not dominated by one person)
- Organizational diversity (contributors from different companies)

**Scoring**:

- 10/10: 5+ organizations contributing regularly
- 7/10: 3+ organizations or 10+ individual contributors
- 5/10: 5+ individual contributors
- 3/10: 2-4 contributors
- 0/10: Single contributor

**Important**: This is a **health signal**, not a security requirement.

### Organic Growth vs. Artificial Inflation

**Legitimate ways to improve**:

1. **Lower contribution barriers**:

   ```markdown
   # CONTRIBUTING.md

   ## Quick Start for Contributors

   No CLA required. Small PRs welcome.

   1. Fork the repository
   2. Create a feature branch
   3. Make your changes
   4. Run `make test`
   5. Submit PR

   We merge quickly and appreciate all contributions.
   ```

2. **Label good first issues**:

   ```yaml
   # .github/labels.yml
   - name: "good first issue"
     description: "Good for newcomers"
     color: "7057ff"
   ```

3. **Mentorship programs**:
   - Hacktoberfest participation
   - Google Summer of Code
   - Outreachy

4. **Corporate contributions**:
   - Open source Friday at companies
   - Encourage employees of partner companies to contribute

**Artificial patterns to avoid**:

- Creating fake accounts to inflate contributor count
- Trivial commits from team members ("fix typo" commits)
- Requiring all team members to commit something

**Reality check**: If your project genuinely has a single maintainer, that's fine. Scorecard reflects reality.

### For Single-Maintainer Projects

**Accept the score**: Contributors check reflects actual project health.

**Focus on**:

- Clear documentation for future contributors
- Bus factor mitigation through documentation
- Succession planning in README

**Example**:

```markdown
# Maintenance Status

Currently maintained by @username. Seeking co-maintainers.

If interested in becoming a maintainer:
1. Submit 3+ quality PRs
2. Participate in issue discussions
3. Contact @username to discuss access
```

### For Organizations

**Internal contributors count**:

Multiple engineers from the same company count as separate contributors.

**Cross-team contributions**:

Encourage contributions from different teams:

```markdown
# Project owned by Platform Team
# Security Team contributions welcome
# Product Team contributions for integrations
```

**Track contributor diversity**:

```bash
# Contributors by organization (from commit email domains)
git log --format='%ae' | sed 's/.*@//' | sort | uniq -c | sort -rn
```

### Troubleshooting

#### Score is 0 despite multiple team members

**Check**: Are commits authored by different users?

```bash
# List unique authors
git log --format='%an <%ae>' | sort | uniq
```

**Cause**: If all commits show same author, Scorecard sees single contributor.

**Solution**: Ensure each team member commits with their own GitHub account.

#### Contractor commits under my account

**Problem**: Contractors using maintainer's credentials.

**Solution**: Create GitHub accounts for contractors or use commit co-authoring:

```bash
# Co-authored commit
git commit -m "Feature implementation

Co-authored-by: Contractor Name <contractor@email.com>"
```

#### Open source project, but company-internal contributions

**Pattern**: This is fine. Contributors from the same company still count as separate contributors.

**Example**: Google has thousands of engineers contributing to Kubernetes. All from Google, but diverse contributor base.

---
