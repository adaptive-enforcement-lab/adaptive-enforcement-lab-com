# Tier 2 Additional Priorities

!!! tip "Key Insight"
    SAST and security policies formalize security practices.

## Priority 4: SAST (1 to 2 hours)

**Target**: SAST 10/10

**Fix**: Add static analysis security testing to workflows.

### For Go Projects: GoSec

```yaml
name: Security

on: [push, pull_request]

jobs:
  gosec:
    permissions:
      contents: read
      security-events: write
    runs-on: ubuntu-latest
    steps:

      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - name: Run GoSec

        uses: securego/gosec@master
        with:
          args: '-no-fail -fmt sarif -out gosec.sarif ./...'

      - name: Upload SARIF

        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: gosec.sarif

```bash
### For Multiple Languages: CodeQL

```yaml
name: CodeQL

on: [push, pull_request]

jobs:
  analyze:
    permissions:
      actions: read
      contents: read
      security-events: write
    runs-on: ubuntu-latest
    steps:

      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: github/codeql-action/init@v3

        with:
          languages: javascript, python

      - uses: github/codeql-action/autobuild@v3

      - uses: github/codeql-action/analyze@v3

```bash
**CodeQL supports**: JavaScript, TypeScript, Python, Ruby, Java, Kotlin, Go, C, C++

### Results in GitHub Security Tab

SARIF upload creates alerts in:

- **Security → Code scanning alerts**
- Visible on PRs as check annotations
- Blocks merge if critical issues found (configurable)

**Impact**: Automated detection of security vulnerabilities in code. Continuous monitoring as code changes.

---

## Priority 5: Advanced Branch Protection (1 hour)

**Target**: Branch-Protection 7/10 → 9/10

**Fix**: Increase review requirements in repository settings.

### Settings Path

**Settings → Branches → Branch protection rules → main**

### Additional Settings for Tier 2

- ✅ **Required approvals**: Increase from **1** to **2**
  - Two reviewers must approve before merge
  - Higher confidence in code quality

- ✅ **Require approval of the most recent reviewable push**
  - Prevents PR author from bypassing review by pushing after approval
  - Forces re-review when code changes

- ✅ **Require conversation resolution before merging**
  - All review comments must be resolved
  - Ensures feedback is addressed

### Optional (Consider Based on Team)

- ⚠️ **Dismiss stale pull request approvals when new commits are pushed**
  - Already enabled in Tier 1
  - Verify it's still active

- ⚠️ **Require linear history**
  - No merge commits, only rebase or squash
  - Cleaner git history but may complicate workflow

**Note for Small Teams**: Teams smaller than 3 people may not be able to require 2 reviewers. Document this exception if applicable.

**Impact**: Prevents PR author from bypassing reviews by pushing new commits after approval. Higher quality gate before merge.

---

## Checkpoint: Score 8 → 9

After implementing all Priority 1-5 fixes:

- ✅ SLSA Level 3 provenance implemented (build integrity proven)
- ✅ All release assets signed (including source archives)
- ✅ Dependencies pinned to SHA digests (with documented exceptions)
- ✅ Static analysis running in CI (SAST integrated)
- ✅ Advanced branch protection enabled (2 reviewers, recent push approval)

**Expected Scorecard improvements**:

| Check | Before | After |
| ----- | ------ | ----- |
| Signed-Releases | 8/10 | 10/10 |
| Pinned-Dependencies | 5/10 | 10/10 (with documented exceptions) |
| SAST | 0/10 | 10/10 |
| Branch-Protection | 7/10 | 9/10 |

**Result**: Advanced supply chain security. Build provenance cryptographically proves artifact origins. Dependencies locked to specific versions. Static analysis catches vulnerabilities.

---

## Troubleshooting

### "SLSA provenance generation fails"

**Check**: Are hashes base64-encoded?

```bash
# Correct format

sha256sum files* | base64 -w0

```bash
**Check**: Is workflow using version tag `@v2.1.0`?

### "Signed-Releases still at 8/10 after SLSA"

**Check**: Is `.intoto.jsonl` file present in release assets?

**Fix**: Ensure `upload-assets: true` in SLSA workflow

### "Pinned-Dependencies flagging SLSA workflow"

**Expected**: `slsa-framework/slsa-github-generator@v2.1.0` requires version tag

**Action**: Document exception in Renovate config and PR descriptions

### "SAST failing on every PR"

**Adjust sensitivity**: Use `-no-fail` flag for GoSec or configure CodeQL thresholds

**Review findings**: Some may be false positives. Document exceptions.

### "Can't get 2 reviewers on small team"

**Document exception**: Add comment in PR template explaining team size constraint

**Alternative**: Enable "Require approval of most recent push" for extra protection

---

## Related Content

- **[Score Progression Overview](../score-progression.md)** - Full roadmap from 7 to 10
- **[Tier 1 Guide](tier-1.md)** - Prerequisites: Token-Permissions, Security-Policy, etc.
- **[Tier 3 Guide](tier-3.md)** - Next steps: CII badge, fuzzing, perfect branch protection
- **[SLSA Provenance](../../../enforce/slsa-provenance/slsa-provenance.md)** - Complete implementation guide
- **[Stuck at 8 Blog](../../../blog/posts/2025-12-18-scorecard-stuck-at-eight.md)** - Real-world SLSA breakthrough

---

## Next Steps

**After reaching 9/10**:

Ready for [Tier 3: Score 9 to 10](tier-3.md) with CII badge, selective fuzzing, and ongoing maintenance.

**Not ready for Tier 3 yet?**

Focus on stabilization:

- Monitor SLSA workflow for several releases
- Verify provenance validation works
- Ensure SAST findings are actionable
- Let team adapt to 2-reviewer requirement

**Remember**: Tier 2 represents advanced supply chain security. Most projects should aim for 9/10. Tier 3 is selective improvements with diminishing returns.

---

*Build provenance implemented. Dependencies locked. Static analysis integrated. Supply chain security proven cryptographically.*
