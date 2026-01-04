---
title: Automated PR Reviews
description: Configure GitHub Actions workflows to run automated security checks on every pull request with fast feedback loops and branch protection enforcement rules.
---
# Automated PR Reviews

GitHub Actions can run security checks on every pull request and provide actionable feedback inline.

---

## Tactic 1: Automated PR Reviews

Security checks that run on every pull request create a safety net before code reaches production.

### Implementation Steps

1. **Create GitHub Actions workflow (`.github/workflows/security.yml`):**

   ```yaml
   name: Security Checks
   on:
     pull_request:
       branches: [main, develop]

   jobs:
     secret-scanning:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
           with:
             fetch-depth: 0

         - name: Run Gitleaks
           uses: gitleaks/gitleaks-action@v2

     dependency-check:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4

         - name: Run Trivy
           uses: aquasecurity/trivy-action@master
           with:
             scan-type: 'fs'
             scan-ref: '.'
             format: 'sarif'
             output: 'trivy-results.sarif'

         - name: Upload to GitHub Security
           uses: github/codeql-action/upload-sarif@v2
           with:
             sarif_file: 'trivy-results.sarif'

     sast:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4

         - name: Run Semgrep
           uses: returntocorp/semgrep-action@v1
           with:
             config: >-
               p/security-audit
               p/owasp-top-ten
   ```

2. **Configure branch protection rules:**
   - Require status check: "Security Checks" must pass
   - Allow force push only for admins
   - Require review from code owners

3. **Add review automation:**

   ```yaml
   - name: Comment on PR with findings
     if: failure()
     uses: actions/github-script@v7
     with:
       script: |
         github.rest.issues.createComment({
           issue_number: context.issue.number,
           owner: context.repo.owner,
           repo: context.repo.repo,
           body: '⚠️ Security checks found issues. Review the details above.'
         })
   ```

### Metrics to Track

- **PR Check Pass Rate**: % of PRs passing security checks (target: >95%)
- **Mean Time to Remediate (MTTR)**: Average time from check failure to fix
- **False Positive Rate**: Issues that aren't actually security problems
- **Developer Velocity**: Time PR blocked by security checks (target: <15 min median)

### Common Pitfalls

- **Blocking Everything**: Too many checks force developers to work around them. Focus on critical issues.
- **Slow Feedback**: Checks taking >10 minutes kill iteration speed. Parallelize, cache, optimize.
- **Useless Output**: Errors without remediation steps get ignored. Provide clear actions in comments.
- **Alert Fatigue**: Too many false positives reduce credibility. Tune carefully.

!!! success "Fast Feedback Wins"
    PRs with security checks completing in <5 minutes have 95%+ adoption. Above 10 minutes, developers start finding workarounds. Speed matters as much as accuracy.

### Success Criteria

- >95% of PRs pass security checks on first attempt (after pre-commit/IDE fixes)
- <10 minute median check execution time
- <5% false positive rate
- Developers ship security-compliant code without workarounds

---

## Tactic 2: CI/CD Pipeline Integration

Security checks should be integrated into your CI/CD pipeline to prevent insecure code from reaching production.

### Implementation Steps

1. **Add security scanning to build pipeline:**

   ```yaml
   # Example: Jenkins pipeline
   pipeline {
     agent any
     stages {
       stage('Security Scan') {
         parallel {
           stage('SAST') {
             steps {
               sh 'semgrep --config=auto --sarif > semgrep.sarif'
             }
           }
           stage('Dependency Check') {
             steps {
               sh 'trivy fs --format sarif . > trivy.sarif'
             }
           }
           stage('Secret Scan') {
             steps {
               sh 'gitleaks detect --verbose --redact'
             }
           }
         }
       }
       stage('Upload Results') {
         steps {
           archiveArtifacts artifacts: '*.sarif'
         }
       }
     }
   }
   ```

2. **Set quality gates:**
   - Block deployment if critical vulnerabilities found
   - Require security review for high-severity issues
   - Alert on medium-severity findings (non-blocking)

3. **Configure fail-fast behavior:**

   ```yaml
   # Example: GitHub Actions fail-fast
   strategy:
     fail-fast: true
     matrix:
       check: [sast, secrets, dependencies]
   ```

### Metrics to Track

- **Pipeline Security Coverage**: % of projects with security scans (target: 100%)
- **Scan Execution Time**: Time added to pipeline by security checks (target: <5 min)
- **Block Rate**: % of deployments blocked by security gates
- **Bypass Frequency**: How often security gates are overridden (target: <1%)

### Common Pitfalls

- **Too Many Blockers**: Everything blocks deployment. Focus on critical and high severity only.
- **Slow Scans**: Security adds 20 minutes to pipeline. Parallelize and cache.
- **No Remediation Path**: Deployment blocked but no guidance on fix. Provide actionable feedback.

### Success Criteria

- 100% of production deployments pass security scans
- <5 minutes added to pipeline by security checks
- <1% of deployments bypass security gates
- Zero critical vulnerabilities reach production

---

## Related Resources

- [Pre-Commit Hooks & IDE Integration](pre-commit-ide.md) - Earlier shift-left practices
- [Scorecards & Dashboards](scorecards-dashboards.md) - Tracking PR check effectiveness
- [Notifications & Badges](notifications-badges.md) - Alert routing for failed checks

---

## Integration: Making CI Blocks Work

CI/CD security checks are effective when:

1. **CI blocks deployment** - Automated gates prevent security debt from reaching production
2. **Feedback is fast** - Checks complete in <10 minutes
3. **Output is actionable** - Every failure includes remediation steps
4. **False positives are rare** - <5% of failures are not real issues

The goal: Make security validation an automatic, fast, and trusted part of your deployment pipeline.
