# Tier 1 Troubleshooting

!!! tip "Key Insight"
    Common implementation challenges have well-documented solutions.

## Troubleshooting

### "Token-Permissions alerts still appearing"

**Check**: Are permissions defined at workflow level?

```yaml
# Wrong - permissions at workflow level

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
```

**Fix**: Move to job level, set workflow level to `permissions: {}`

### "Security-Policy not detected"

**Check**: Is file named exactly `SECURITY.md` (not `security.md`)?

**Check**: Is it in repository root, not `.github/` directory?

### "Dependency-Update-Tool still 0/10"

**Check**: Has Renovate created its first PR? May take 24 hours after setup.

**Check**: Is `renovate.json` valid JSON? Use JSON linter.

### "Branch-Protection settings grayed out"

**Cause**: You don't have admin access to repository.

**Fix**: Ask repository owner to enable settings or grant admin access.

### "Can't remove binaries without force push"

**Decision**: Accept binaries in history or coordinate force push with team.

**Alternative**: Focus on preventing new binaries. Document exception for historical ones.

---

## Related Content

- **[Score Progression Overview](../score-progression.md)** - Full roadmap from 7 to 10
- **[Tier 2 Guide](tier-2.md)** - Next steps: SLSA provenance and dependency pinning
- **[Scorecard Compliance](../scorecard-compliance.md)** - Detailed compliance patterns
- **[16 Alerts Overnight](../../../blog/posts/2025-12-20-sixteen-alerts-overnight.md)** - Real-world Token-Permissions fix

---

## Next Steps

**After reaching 8/10**:

Ready for [Tier 2: Score 8 to 9](tier-2.md) with SLSA provenance and comprehensive dependency pinning.

**Not ready for Tier 2 yet?**

Focus on stability:

- Monitor Renovate/Dependabot PRs for a few weeks
- Ensure team adapts to branch protection workflow
- Run Scorecard regularly to catch regressions

**Remember**: Tier 1 fixes have high ROI. All projects should implement them.

---

*Quick wins completed. Security hygiene established. Ready for advanced supply chain protections.*
