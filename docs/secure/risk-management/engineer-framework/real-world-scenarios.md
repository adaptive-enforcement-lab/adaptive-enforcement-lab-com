---
tags:
  - risk-management
  - case-studies
  - vulnerability-management
description: >-
  Real-world vulnerability scenarios with complete risk assessments, decision rationale, and execution plans. Log4Shell, dependency vulnerabilities, and Kubernetes exploits.
---

# Real-World Vulnerability Scenarios

!!! note "Learn from Log4Shell"
    Log4Shell is the perfect case study for blast radius and exploitability. Transitive dependency with 90% coverage. Network-exploitable. No auth required. In-the-wild within hours. This is what CRITICAL looks like.

## Scenario 1: Log4Shell (CVE-2021-44228)

**The Facts**:

- CVSS: 10.0 CRITICAL
- Attack Vector: Network
- Prerequisites: None (unauthenticated RCE)
- Exploitation: Trivial (public PoC within hours)
- Status: In-the-wild within 24 hours of disclosure

**Risk Assessment**:

| Factor | Score | Reasoning |
|--------|-------|-----------|
| Impact | 4 | Complete system compromise, RCE |
| Likelihood | 4 | Active exploitation, trivial to weaponize |
| Exploitability | 4 | No auth, network-adjacent, <5 min PoC |
| Blast Radius Multiplier | 5.0 | Transitive dependency in 90% of Java services |
| **Total Risk** | **320 (CRITICAL)** | |

**Decision**: **Patch within 4 hours**

**Execution**:

1. Identify all Log4j-dependent services (automated scan)
2. Stage updates in parallel (don't serialize)
3. Canary deploy 5% → 25% → 100% within 2 hours
4. Monitor error rates and exceptions
5. Rollback plan: Previous version tagged in git, ready to deploy

**Why This Speed**:

- Active exploitation started immediately upon disclosure
- No complex prerequisites; unauthenticated RCE
- Affects backbone of infrastructure (90% coverage)
- Cost of patch: ~30 minutes per service
- Cost of breach: Complete infrastructure compromise

## Scenario 2: CVE-2024-1234 (Hypothetical Node.js Package)

**The Facts**:

- Package: `express-session` (web session middleware)
- CVSS: 7.5
- Vulnerability: Session fixation in specific configuration
- Requirements: User must be using non-default session store settings
- Exploitation: No public PoC yet

**Risk Assessment**:

| Factor | Score | Reasoning |
|--------|-------|-----------|
| Impact | 3 | Session hijacking possible, user auth bypass |
| Likelihood | 2 | Known attack path, but requires specific config |
| Exploitability | 2 | Public PoC not available yet, requires setup |
| Your Blast Radius | 1.5 | Only 3 services use this package; standard config |
| **Total Risk** | **13.5 (LOW-MEDIUM)** | |

**Decision**: **Schedule for next sprint (7-14 days)**

**Execution**:

1. Audit which services use this package and which use vulnerable config
2. Add to sprint planning, estimate ~2 hours per service
3. Create test case for the specific configuration
4. Deploy in standard change request window
5. Monitor session metrics post-deploy

**Why This Timeline**:

- No public exploits exist (lowers likelihood)
- Requires specific non-standard configuration (limits blast radius)
- Affects only 3 services, not infrastructure backbone
- One-week delay acceptable; risk is low

## Scenario 3: CVE-2024-5678 (Kubernetes Privilege Escalation)

**The Facts**:

- Vulnerability: Privilege escalation in Kubernetes kubelet
- CVSS: 8.4
- Requirements: Pod with specific Linux capability
- Exploitation: Requires knowledge of Kubernetes internals
- Status: PoC released; not yet in standard pentesting tools

**Risk Assessment**:

| Factor | Score | Reasoning |
|--------|-------|-----------|
| Impact | 4 | Node compromise, lateral movement to host |
| Likelihood | 2 | Known path, but requires specific pod setup |
| Exploitability | 2 | PoC exists, but not automated; requires K8s knowledge |
| Your Blast Radius | 4.0 | ALL pods affected IF they have the capability |
| **Total Risk** | **64 (CRITICAL)** | |

**Decision**: **Patch within 48 hours** (Emergency path)

**Execution**:

1. **Immediate (Hour 0-2)**:
   - Disable the vulnerable Linux capability cluster-wide (temporary mitigation)
   - This prevents exploitation immediately
   - Some workloads may need reconfiguration

2. **Short-term (Hour 2-24)**:
   - Update kubelet to patched version
   - Test in staging environment
   - Prepare canary deployment plan

3. **Deployment (Hour 24-48)**:
   - Use managed Kubernetes auto-updates if available
   - Manual node drain and update if necessary
   - Monitor kubelet logs for anomalies

**Why This Approach**:

- Blast radius is ALL nodes (infrastructure layer)
- Can't accept this risk even with workaround
- But can reduce urgency from 4 hours to 48 hours via compensating control (disable capability)
- Buying time to test properly without exposing infrastructure

!!! tip "Transitive Dependencies Are Your Problem"
    You own every line of code in production, including dependencies of dependencies. If your library doesn't update, fork and patch yourself. Don't wait for upstream.

## Scenario 4: CVE-2024-9999 (Transitive Dependency)

**The Facts**:

- Vulnerable package: `old-crypto-lib@1.2.3`
- Used by: `payment-sdk@3.0` (your payment library)
- Used by: Your backend service
- CVSS: 6.2
- Attack: Memory corruption in specific crypto operation
- Status: Research PoC only

**Risk Assessment**:

| Factor | Score | Reasoning |
|--------|-------|-----------|
| Impact | 3 | Potential payment data exposure |
| Likelihood | 1 | No public exploit, requires specific crypto operation |
| Exploitability | 2 | Attack requires custom implementation |
| Your Blast Radius | 2.5 | Affects payment processing only |
| **Total Risk** | **7.5 (LOW)** | |

**BUT**: This is a transitive dependency. The challenge:

```text
your-service → payment-sdk (3.0) → old-crypto-lib (1.2.3)
                   ↓
            Check: Does payment-sdk 3.1+ exist?
            YES: Upgrade payment-sdk only
            NO: Can we use payment-sdk from source? Patch ourselves?
```

**Decision**: **Upgrade payment-sdk in next release (30 days)**

**BUT If payment-sdk hasn't updated yet**:

```text
Option 1: Wait for payment-sdk maintainer (risky if long delay)
Option 2: Fork and patch ourselves (maintenance burden)
Option 3: Implement compensating control (don't use vulnerable crypto path)
Option 4: Review if we actually use the vulnerable function
```

**Execution**:

1. Check `payment-sdk` GitHub issues (already reported?)
2. Contact maintainer; offer help if needed
3. If no movement in 2 weeks, fork and patch
4. Add test case for the vulnerable crypto operation
5. Monitor for payment-sdk update

---

*Real-world scenarios show context matters. CVSS is a starting point, not the decision.*
