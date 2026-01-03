---
description: >-
  Integrate CodeQL or Semgrep for automated vulnerability scanning. SAST tools detect security flaws before code review with zero manual configuration.
---

# SAST Check

!!! tip "Key Insight"
    SAST detects security vulnerabilities before code review.

## SAST (Static Application Security Testing)

**Target**: 10/10 by integrating static analysis tools

**What it checks**: Whether repository uses static analysis security testing in CI.

**Why it matters**: SAST catches security vulnerabilities (SQL injection, XSS, hardcoded secrets) before code reaches production.

### What Scorecard Detects

Scorecard looks for evidence of SAST tools in workflows:

**Detected tools**:

- CodeQL (GitHub's semantic code analysis)
- Snyk (dependency and code scanning)
- SonarQube / SonarCloud
- Semgrep (lightweight static analysis)
- Checkmarx, Fortify, Veracode (enterprise tools)

**Detection method**: Searches `.github/workflows/*.yml` for tool names and patterns.

### Quick Win: CodeQL (Easiest)

GitHub provides CodeQL for free on public repositories.

Create `.github/workflows/codeql.yml`:

```yaml
name: CodeQL

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * 1'  # Weekly Monday scan

permissions: {}

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write  # Upload results to GitHub Security tab

    strategy:
      fail-fast: false
      matrix:
        language: ['javascript', 'python']  # Adjust for your stack

    steps:
      - name: Checkout repository
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Initialize CodeQL
        uses: github/codeql-action/init@012739e5082ff0c22ca6d6ab32e07c36df03c4a4  # v3.22.12
        with:
          languages: ${{ matrix.language }}

      - name: Autobuild
        uses: github/codeql-action/autobuild@012739e5082ff0c22ca6d6ab32e07c36df03c4a4  # v3.22.12

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@012739e5082ff0c22ca6d6ab32e07c36df03c4a4  # v3.22.12
```

**Supported languages**:

- JavaScript/TypeScript
- Python
- Java/Kotlin
- Go
- C/C++
- C#
- Ruby

**Result**: Scorecard detects `github/codeql-action` and gives SAST 10/10.

### Alternative: Semgrep (Multi-language)

Semgrep is lightweight and supports many languages.

Create `.github/workflows/semgrep.yml`:

```yaml
name: Semgrep

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions: {}

jobs:
  semgrep:
    name: Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write

    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: returntocorp/semgrep-action@713efdd345f3035192eaa63f56867b88e63e4e5d  # v1
        with:
          config: auto  # Use Semgrep's curated rulesets
```

**Result**: Scorecard detects `semgrep-action` and gives SAST 10/10.

### Enterprise: SonarCloud

SonarCloud provides comprehensive analysis with quality gates.

Create `.github/workflows/sonarcloud.yml`:

```yaml
name: SonarCloud

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions: {}

jobs:
  sonarcloud:
    name: SonarCloud Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          fetch-depth: 0  # Full history for better analysis

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

**Setup required**:

1. Sign up at sonarcloud.io
2. Import repository
3. Add `SONAR_TOKEN` to repository secrets
4. Create `sonar-project.properties` in repository root

### Choosing a SAST Tool

| Tool | Best For | Setup | Cost |
| ---- | -------- | ----- | ---- |
| CodeQL | GitHub-native, deep analysis | 5 minutes | Free (public repos) |
| Semgrep | Quick setup, custom rules | 2 minutes | Free tier available |
| SonarCloud | Quality metrics + security | 15 minutes | Free (open source) |
| Snyk | Dependency + code scanning | 10 minutes | Free tier available |

**Recommendation**: Start with CodeQL for simplest setup.

### SAST Results Integration

**GitHub Security Tab**:

Most tools upload results to Security → Code scanning alerts.

**Required permission**:

```yaml
permissions:
  security-events: write  # Upload to Security tab
```

**Workflow failure**:

Configure whether findings fail the build:

```yaml
- name: Perform CodeQL Analysis
  uses: github/codeql-action/analyze@012739e5082ff0c22ca6d6ab32e07c36df03c4a4
  with:
    fail-on: error  # Fail workflow on high-severity findings
```

### Custom SAST Rules

**CodeQL custom queries**:

Create `.github/codeql/custom-queries.ql`:

```ql
import python

from Call call
where call.getFunc().getName() = "eval"
select call, "Dangerous use of eval()"
```

Reference in workflow:

```yaml
- name: Initialize CodeQL
  uses: github/codeql-action/init@012739e5082ff0c22ca6d6ab32e07c36df03c4a4
  with:
    languages: python
    queries: .github/codeql/custom-queries.ql
```

**Semgrep custom rules**:

Create `.semgrep/rules.yml`:

```yaml
rules:
  - id: hardcoded-secret
    pattern: |
      password = "..."
    message: Hardcoded password detected
    severity: ERROR
    languages: [python]
```

### Troubleshooting

#### CodeQL autobuild failing

**Cause**: Complex build process not auto-detected.

**Solution**: Replace autobuild with manual build steps:

```yaml
- name: Build
  run: |
    npm install
    npm run build
```

#### SAST not detected by Scorecard

**Check**: Is SAST tool name in workflow file? Scorecard searches for keywords.

**Check**: Is workflow in `.github/workflows/`? Scorecard only checks this directory.

#### Too many false positives

**Solution**: Tune SAST rules to reduce noise.

**CodeQL**:

```yaml
with:
  queries: +security-and-quality  # Balanced ruleset
```

**Semgrep**:

```yaml
with:
  config: p/ci  # CI-optimized rules (fewer false positives)
```

#### Private repos don't have CodeQL

**Solution**: CodeQL is free for public repos, paid for private repos. Use Semgrep or Snyk instead.

---

## Remediation Priority

**Order of implementation** for fastest score improvement:

1. **Binary-Artifacts** (1 to 2 hours) - Remove binaries from git, update `.gitignore`
2. **SAST** (0.5 to 1 hour) - Add CodeQL workflow
3. **Pinned-Dependencies** (1 to 2 hours) - Configure Renovate with SHA pinning
4. **Dangerous-Workflow** (2 to 4 hours) - Audit all workflows, fix `pull_request_target` patterns

**Total estimated effort**: 4.5 to 9 hours for all supply chain checks.

---

## Check Interactions

**Pinned-Dependencies + Renovate**:

Renovate automates SHA pinning and creates update PRs. Configure once, automated forever.

**Dangerous-Workflow + Token-Permissions**:

Job-level permissions (Token-Permissions) reduce blast radius of Dangerous-Workflow exploits.

**SAST + Pinned-Dependencies**:

SAST can detect hardcoded secrets that attackers might target through workflow exploits.

**Binary-Artifacts + Signed-Releases**:

Removing binaries from git forces use of GitHub Releases, which enables cryptographic signing.

---

## Related Content

**Existing guides**:

- [Scorecard Compliance](../../scorecard-compliance.md) - Core patterns including Token-Permissions and Pinned-Dependencies
- [Scorecard Workflow Examples](../../scorecard-workflow-examples.md) - Production workflows combining these patterns
- [Tier 1 Progression](../../score-progression/tier-1.md) - Quick wins including Binary-Artifacts removal

**Blog posts**:

- [16 Alerts Cleared Overnight](../../../../blog/posts/2025-12-20-sixteen-alerts-overnight.md) - Token-Permissions mass fix
- [Stuck at 8: Journey to 10/10](../../../../blog/posts/2025-12-18-scorecard-stuck-at-eight.md) - SLSA and Signed-Releases breakthrough

**Related patterns**:

- [SLSA Provenance](../../../../enforce/slsa-provenance/slsa-provenance.md) - Signed-Releases implementation

---

## Next Steps

1. **Quick scan**: Run Scorecard locally to get baseline

   ```bash
   docker run -e GITHUB_TOKEN=$GITHUB_TOKEN gcr.io/openssf/scorecard:stable \
     --repo=github.com/your-org/your-repo
   ```

2. **Low-hanging fruit**: Fix Binary-Artifacts and SAST first (2 to 3 hours total)

3. **Automation**: Configure Renovate for automated SHA pinning

4. **Audit**: Review all workflows for Dangerous-Workflow patterns

5. **Monitor**: Add Scorecard to CI for regression prevention

**Remember**: Supply chain security is layers. No single check protects everything. Implement all four for comprehensive protection.

---

*Supply chain checks are high-impact, not high-effort. Clear them first before moving to code review and security practices checks.*
