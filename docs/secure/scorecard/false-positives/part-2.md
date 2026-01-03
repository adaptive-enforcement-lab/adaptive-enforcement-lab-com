## Binary Test Fixtures

These binaries are test fixtures only, not production code.
Scorecard flags them, but removing them provides no security benefit.

- sample.pdf: 2KB PDF for parser testing
- test-image.png: 1KB image for upload testing
```

**Expected score**: 8/10 to 9/10 depending on fixture size

#### False Positive: Font Files in Documentation

**Pattern**: Scorecard sometimes flags web fonts in docs.

```text
docs/
  assets/
    fonts/
      custom-font.woff2  # Sometimes flagged
```

**Why false positive**: Fonts are assets, not executable code.

**Resolution**:

Check if Scorecard actually flags it (varies by file type):

```bash
# Run Scorecard locally to confirm
scorecard --repo=github.com/your-org/your-repo --checks=Binary-Artifacts
```

If flagged:

- Move fonts to CDN
- Use system fonts
- Document as acceptable exception

---

### SAST

#### False Positive: No Code to Analyze

**Pattern**: Documentation-only repos flagged for no SAST.

**Example**: This documentation site has no application code.

**Why false positive**: SAST tools analyze application code. Markdown doesn't need static analysis.

**Resolution**:

Accept 0/10 for SAST on documentation repositories. The check doesn't apply.

**Alternative**: Run markdownlint in CI and document it:

```yaml
# .github/workflows/lint.yml
- name: Markdown lint (satisfies SAST intent)
  uses: DavidAnson/markdownlint-cli2-action@v16
```

Scorecard won't recognize this as SAST, but it serves the same purpose.

#### False Positive: Language Not Supported

**Pattern**: Project uses language without mainstream SAST tools.

**Why flagged**: Scorecard looks for popular SAST tools (CodeQL, Semgrep, SonarCloud).

**Resolution**:

Document language-specific linting:

```yaml
# For Rust projects
- name: Clippy (Rust static analysis)
  run: cargo clippy -- -D warnings

# For Shell scripts
- name: ShellCheck
  run: shellcheck **/*.sh
```

**Expected score**: 0/10 from Scorecard (doesn't recognize these)

**When to report**: If widely-used linters exist for your language, open an issue asking Scorecard to recognize them.

---

## Code Review & Quality Checks

### Code-Review

#### False Positive: Import/Migration Commits

**Pattern**: Bulk import commits have no PR review.

```bash
$ git log
a1b2c3d Initial commit - import from internal repo (no PR review)
```

**Why flagged**: Scorecard analyzes last 30 days of commits.

**Why false positive**: Historical imports can't have review.

**Resolution**:

Wait 30 days. Scorecard only checks recent commits.

**Alternative**: Rewrite history with synthetic review (not recommended):

```bash
# Don't do this - introduces audit trail gaps
git rebase -i --root
```

Better to accept 8/10 for first month, then achieve 10/10.

#### False Positive: Bot Commits

**Pattern**: Dependabot/Renovate commits flagged as unreviewed.

**Why flagged**: Auto-merge means bot both creates and merges PR.

**Why sometimes false positive**: These are reviewed by CI checks, not humans.

**Resolution**:

Require human approval for dependency updates:

```yaml
# .github/renovate.json
{
  "packageRules": [
    {
      "matchUpdateTypes": ["major"],
      "dependencyDashboardApproval": true
    }
  ]
}
```

Or accept that automated dependency updates are a trade-off:

- Lower Code-Review score
- Faster security patches
- CI verification instead of human review

**Our position**: Human review for major updates, auto-merge for patch updates.

---

### Branch-Protection

#### False Positive: Admin Bypass Required

**Pattern**: Scorecard penalizes allowing admins to bypass protections.

**Why flagged**: Admins bypassing protections defeats the purpose.

**Why sometimes legitimate**:

- Small teams (1-3 people) where all members are admins
- Emergency hotfix scenarios
- Repositories where admins are the security reviewers

**Resolution**:

Decide based on team structure:

**Large teams (5+ people)**: Enforce on admins

```hcl
resource "github_branch_protection" "main" {
  repository_id  = github_repository.repo.node_id
  pattern        = "main"
  enforce_admins = true  # No bypass allowed
}
```

**Small teams (1-3 people)**: Allow admin bypass, document rationale

```hcl
resource "github_branch_protection" "main" {
  repository_id  = github_repository.repo.node_id
  pattern        = "main"
  enforce_admins = false  # Allow bypass for emergencies
}
```

Document in `SECURITY.md`:

```markdown
## Branch Protection

Admins can bypass branch protection for emergency hotfixes.
All bypasses are logged and reviewed in monthly security audits.
```

**Expected score**: 9/10 with bypass allowed, 10/10 without

#### False Positive: Required Checks Don't Exist

**Pattern**: Scorecard wants required status checks, but repo has no CI.

**Why flagged**: Branch protection without required checks is weak.

**Why sometimes false positive**: Documentation repos may not need CI.

**Resolution**:

Add minimal CI workflow:

```yaml
# .github/workflows/validate.yml
name: Validate

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - name: Validate links
        run: echo "Link validation would run here"
```

Then require it in branch protection:

```text
Settings > Branches > Branch protection rules
✓ Require status checks to pass before merging
  ✓ validate
```

---

## Security Practice Checks

### Security-Policy

#### False Positive: Security Policy in Non-Standard Location

**Pattern**: Security policy exists but not at `SECURITY.md`.

**Examples**:

- `docs/SECURITY.md`
- `README.md` section about security
- `.github/SECURITY.yml`

**Why flagged**: Scorecard only checks root `SECURITY.md` or `.github/SECURITY.md`.

**Resolution**:

Move or duplicate to expected location:

```bash
# Create standard location
cp docs/SECURITY.md SECURITY.md
```

Or add at root with link:

```markdown
<!-- SECURITY.md -->
# Security Policy

See docs/SECURITY.md for our complete security policy.
```

**Expected score**: 10/10 after adding root file

---

### CII-Best-Practices

#### False Positive: Private Repositories

**Pattern**: Private repos can't get CII badge.

**Why**: OpenSSF Best Practices badge requires public projects.

**Resolution**: Accept 0/10 for private repositories. The check doesn't apply.

**Alternative**: If project will be open-sourced, prepare by documenting practices:

```markdown
# COMPLIANCE.md
