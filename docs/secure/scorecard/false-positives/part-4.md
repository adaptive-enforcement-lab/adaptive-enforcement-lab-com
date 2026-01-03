# Resolution Approaches

!!! tip "Key Insight"
    Resolution strategies balance security signal with operational overhead.

## Resolution Approaches

### Fix It (Preferred)

**When to fix**:

- Fix is simple and quick
- Improves security even if false positive
- Pattern is confusing to future maintainers

**Example**:

```yaml
# Flagged: Pull request comment without explicit permissions

on:
  pull_request:

jobs:
  comment:
    runs-on: ubuntu-latest
    steps:
      - run: echo "PR comment"
```

Fix by adding explicit permissions:

```yaml
# Clear: Explicit read-only permissions

on:
  pull_request:

jobs:
  comment:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read
    steps:
      - run: echo "PR comment"
```

Result: Higher score + clearer intent.

---

### Document It (When Necessary)

**When to document**:

- Fix would break functionality
- Legitimate deviation from recommendation
- Context explains why pattern is safe

**Example**:

```yaml
# Admin bypass allowed for emergency hotfixes

# All bypasses logged and reviewed monthly

# Documented in SECURITY.md section 3.2

```

**Where to document**:

1. **Inline comments** - Explain pattern in code
2. **SECURITY.md** - Document security decisions
3. **CONTRIBUTING.md** - Explain workflow choices
4. **PR descriptions** - Context for reviewers

---

### Accept It (Sometimes)

**When to accept**:

- Check doesn't apply to your project type
- Achieving 10/10 provides no security benefit
- Cost of fix exceeds value

**Examples**:

- Documentation repo: Accept 0/10 for SAST
- Private repo: Accept 0/10 for CII-Best-Practices
- Solo project: Accept low Contributors score
- Stable project: Accept lower Maintained score

**Document acceptance**:

```markdown
# SCORECARD.md

## Score Exceptions

| Check | Score | Reason |
|-------|-------|--------|
| SAST | 0/10 | Documentation repo, no application code |
| CII-Best-Practices | 0/10 | Private repository |
| Contributors | 3/10 | Solo-maintained project |

Last reviewed: 2026-01-02
```

---

## Cross-References

**Related guides**:

- [Scorecard Index](index.md) - Overview of all 18 checks
- [Supply Chain Checks](checks/supply-chain.md) - Detailed Pinned-Dependencies exceptions
- [Decision Framework](decision-framework.md) - When to follow vs. deviate from recommendations
- [Score Progression](score-progression.md) - Prioritized remediation roadmap

**External resources**:

- [Scorecard Checks Documentation](https://github.com/ossf/scorecard/blob/main/docs/checks.md)
- [Known Limitations](https://github.com/ossf/scorecard#limitations)
- [Report Issues](https://github.com/ossf/scorecard/issues)

---

**Bottom line**: Perfect scores aren't the goal. Security is. Use Scorecard as a guide, not gospel. Fix what matters, document what doesn't, and move on to real security work.
