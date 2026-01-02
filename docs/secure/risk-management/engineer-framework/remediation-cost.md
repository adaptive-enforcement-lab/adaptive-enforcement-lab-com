---
tags:
  - risk-management
  - cost-benefit
  - remediation
description: >-
  Remediation cost vs. risk analysis framework. Cost calculation, priority scoring, and examples of high vs. low priority patches.
---

# Remediation Cost vs. Risk Analysis

Not all patches are equal. Sometimes the "fix" introduces more risk than the vulnerability.

!!! warning "Sometimes the Patch Costs More Than the Risk"
    A 40-hour refactor to fix a low-risk vulnerability might introduce more bugs than it prevents. Use compensating controls. Accept documented risk. Don't break working systems for cosmetic security.

## Cost Calculation Framework

```text
Remediation Cost = (Testing Time + Deployment Time + Monitoring Time + Rollback Risk)
Risk Reduction = (Current Risk Score) - (Residual Risk After Patch)

Priority = Risk Reduction / Remediation Cost
```

**Examples**:

### High Priority (Simple Patch)

```text
Vulnerability: Minor DoS in deprecated endpoint
Risk Score: 8
Residual Risk: 2 (disable endpoint, 1 hour work)
Remediation Cost: 2 hours (simple delete)
Priority: 6 / 2 = 3.0

Decision: Patch immediately
```

### Medium Priority (Moderate Patch)

```text
Vulnerability: Privilege escalation in sudo
Risk Score: 25
Residual Risk: 8 (configure sudo sudoers, 4 hours)
Remediation Cost: 8 hours (update, test, stage, deploy)
Priority: 17 / 8 = 2.1

Decision: Plan for next sprint
```

### Low Priority (Complex Patch)

```text
Vulnerability: Deprecated library with workaround
Risk Score: 12
Residual Risk: 2 (compensating control works, no patch needed)
Remediation Cost: 40 hours (upgrade, retest, refactor code)
Priority: 10 / 40 = 0.25

Decision: Accept risk, use compensating control
```

## Implementation Checklist

### For Every Vulnerability

- [ ] **Score it**: Calculate risk using Impact × Likelihood × Exploitability matrix
- [ ] **Blast it**: Determine what % of systems are affected
- [ ] **Exploit check**: Is there public PoC? In-the-wild exploitation?
- [ ] **Decide path**: Use decision tree for patch-now vs. later
- [ ] **Plan work**: Estimate testing + deployment + rollback time
- [ ] **Get approval**: Document decision and risk acceptance
- [ ] **Execute**: Follow emergency or standard path
- [ ] **Monitor**: Watch error rates, security logs, metrics
- [ ] **Verify**: Confirm patch was applied and vulnerability is fixed
- [ ] **Document**: Record decision, timeline, lessons learned

!!! warning "Emergency Patches Skip Normal Approval"
    For risk scores >40, patch first, notify later. Don't wait for change request approval. This is the exception to normal process. Document the emergency decision afterward.

### For Patch Emergencies (Risk > 40)

- [ ] Alert on-call team immediately
- [ ] Start remediation WITHOUT waiting for approvals
- [ ] Inform leadership (after starting mitigation, not before)
- [ ] Have rollback plan ready before deploying
- [ ] Use canary deployment (don't go all-in on untested patch)
- [ ] Monitor continuously for 6 hours post-deploy
- [ ] Write incident report immediately after stabilization
- [ ] Schedule blameless postmortem within 24 hours

## Metrics to Track

### Speed Metrics

- **Mean Time to Detect (MTTD)**: When did you learn about the vulnerability?
- **Mean Time to Patch (MTBP)**: How long from disclosure to applied patch?
- **Critical Patch Speed**: What's your fastest emergency patch time?

**Targets**:

- MTTD: < 24 hours (automated CVE alerts)
- MTBP (Critical): < 4 hours
- MTBP (High): < 72 hours
- MTBP (Medium): < 30 days

### Quality Metrics

- **Rollback Rate**: How often do patches require reverting?
- **Security Regression Rate**: Do patches introduce new vulnerabilities?
- **Test Coverage**: Are vulnerable code paths covered by tests?

**Targets**:

- Rollback rate: < 2%
- Security regressions: 0
- Test coverage: 80%+ on critical paths

### Risk Metrics

- **Average Risk Score of Unpatched Vulnerabilities**: How much risk are you carrying?
- **Distribution by Severity**: Are most vulnerabilities low/medium or high/critical?
- **Time-to-Patch by Risk Level**: Do you actually patch critical things faster?

## Glossary

**Blast Radius**: The percentage of your systems, users, or data exposed if the vulnerability is exploited.

**CVSS**: Common Vulnerability Scoring System. A standardized 0–10 scale for vulnerability severity.

**Exploitability**: How easy is it to actually exploit the vulnerability? CVSS component; engineering interpretation matters more than the score.

**Likelihood**: Probability that the vulnerability will be exploited in your environment. Depends on threat landscape, not just the vulnerability itself.

**MTTD**: Mean Time to Detect. How long before you know about a vulnerability?

**MTBP**: Mean Time to Patch. How long from disclosure to deployed fix in production.

**Risk Score**: Composite metric combining impact, likelihood, exploitability, and blast radius.

**Transitive Dependency**: A library that your library depends on (not directly included by you, but still your responsibility to manage).

## Further Reading

- [OWASP Risk Rating](https://owasp.org/www-project-risk-rating-manager/)
- [NIST Security Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5)

---

*Remediation cost matters. Prioritize based on risk reduction per hour of effort.*
