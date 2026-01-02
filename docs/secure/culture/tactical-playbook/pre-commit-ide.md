---
description: >-
  Pre-commit hooks and IDE integration for shift-left security. Fast, auto-fixing checks that catch issues before code review without slowing developers down.
---

# Pre-Commit Hooks & IDE Integration

Shift left without friction. Catch security issues as early as possible, before they reach code review.

---

## Tactic 1: Pre-Commit Hooks (Fast & Auto-Fix)

Pre-commit hooks run before code enters the repository. The critical rule: **they must be fast and auto-fixing**.

### Implementation Steps

1. **Install `pre-commit` framework:**

   ```bash
   pip install pre-commit
   ```

2. **Create `.pre-commit-config.yaml` in your repo:**

   ```yaml
   repos:
     - repo: https://github.com/pre-commit/pre-commit-hooks
       rev: v4.5.0
       hooks:
         - id: detect-private-key
         - id: check-ast
         - id: check-json
         - id: check-yaml
         - id: mixed-line-ending

     - repo: https://github.com/adrienverge/yamllint
       rev: v1.33.0
       hooks:
         - id: yamllint
           args: ['--config-data', '{rules: {line-length: {max: 120}}}']

     - repo: https://github.com/gitleaks/gitleaks
       rev: v8.18.0
       hooks:
         - id: gitleaks

     - repo: https://github.com/hadialqattan/pycln
       rev: v2.4.0
       hooks:
         - id: pycln
           language_version: python3
   ```

3. **Install hooks in local dev environment:**

   ```bash
   pre-commit install
   ```

4. **Run against all files (CI):**

   ```bash
   pre-commit run --all-files
   ```

### Metrics to Track

- **Hook Execution Time**: Average time per commit (target: <2 seconds)
- **Auto-Fixes Applied**: Count of auto-fixed issues per week
- **Bypass Rate**: How often developers skip hooks with `--no-verify` (target: <5%)
- **False Positive Rate**: Legitimate code flagged as insecure

### Common Pitfalls

- **Too Slow**: Hooks taking >5 seconds cause developers to use `--no-verify`. Optimize or move to CI.
- **Too Strict**: Excessive failures discourage use. Start permissive, tighten gradually.
- **No Auto-Fix**: Manual fixes kill adoption. Use tools that auto-correct (like `black`, `yamllint --fix`).
- **Inconsistent Rules**: Different rules on local and CI create confusion. Sync configuration.

!!! warning "Speed Is Critical"
    Hooks taking more than 5 seconds push developers toward `--no-verify`. Every second over 2 seconds reduces adoption by ~15%. Optimize ruthlessly.

### Success Criteria

- Hooks run in <2 seconds on average
- >90% of team members have hooks installed
- <5% bypass rate
- Catching 80%+ of low-risk issues (typos, formatting)

---

## Tactic 2: IDE Integration (Real-Time Feedback)

Developers spend most time in their editor. Real-time security feedback in the IDE catches issues before commit.

### Implementation Steps

1. **Configure IDE extensions for secret detection:**
   - **VS Code**: Install `gitguardian.ggshield` extension
   - **JetBrains**: Install `GitGuardian` plugin
   - **Vim/Neovim**: Use `nvim-lsp` with security rules

2. **Enable inline linting for security rules:**
   - **Semgrep rules** in VS Code (`Semgrep.semgrep` extension)
   - **SonarQube analysis** in JetBrains (SonarLint plugin)
   - **Trivy** scanning (via LSP integrations)

3. **Configure `.editorconfig` for consistency:**

   ```ini
   [*]
   charset = utf-8
   insert_final_newline = true
   trim_trailing_whitespace = true

   [*.{js,ts,jsx,tsx}]
   indent_style = space
   indent_size = 2

   [*.{py}]
   indent_style = space
   indent_size = 4
   ```

4. **Document in onboarding guide:**
   - Link to extension installation
   - Screenshot of expected behavior
   - How to configure for team standards

### Metrics to Track

- **IDE Extension Adoption**: % of team with extension installed
- **Issues Caught Pre-Commit**: Count of security issues IDE caught before commit
- **Time to First Fix**: Average time from issue detection to resolution
- **Developer Satisfaction**: Survey on IDE feedback helpfulness

### Common Pitfalls

- **IDE Noise**: Too many warnings kill effectiveness. Curate the rule set.
- **Configuration Drift**: Developers disable rules because they're too strict. Sync with team standards.
- **Slow Performance**: Heavy analysis slows editor responsiveness. Use fast, lightweight rules for IDE (defer heavy analysis to CI).

### Success Criteria

- >80% of team has IDE extension installed
- IDE catches 30%+ of security issues before CI
- Zero performance impact on editor responsiveness
- Developers report high confidence in IDE feedback

---

## Related Resources

- [Automated PR Reviews](automated-reviews.md) - CI/CD layer security checks
- [Automation & Self-Service Tools](automation-tools.md) - CLI tools for local development
- [Scorecards & Dashboards](scorecards-dashboards.md) - Tracking pre-commit effectiveness

---

## Integration: Making It Stick

Security onboarding is effective when:

1. **Speed beats workarounds** - Every check must be faster than bypassing it
2. **Feedback is immediate** - IDE and pre-commit catch issues in seconds, not hours
3. **Auto-fix is default** - Manual remediation kills adoption
4. **Rules are consistent** - Local, IDE, and CI enforce the same standards

The goal: Make insecure code harder to write than secure code.
