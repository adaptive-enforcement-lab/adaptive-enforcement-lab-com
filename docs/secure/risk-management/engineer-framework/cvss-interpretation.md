---
title: CVSS Score Interpretation for Engineers
tags:
  - risk-management
  - cvss
  - vulnerability-management
description: >-
  CVSS score interpretation for engineers. Understanding CVSS 3.1 components, translating scores to actionable decisions, and real-world vulnerability assessment examples.
---
# CVSS Score Interpretation for Engineers

CVSS (Common Vulnerability Scoring System) is useful but incomplete. Translate base scores to engineering decisions.

## CVSS 3.1 Score Ranges

| CVSS Score | Severity | Engineering Meaning | Our Threshold |
|-----------|----------|---------------------|----------------|
| 9.0–10.0 | **Critical** | Network RCE, no auth, trivial exploit | Patch in 24h |
| 7.0–8.9 | **High** | Network-accessible, requires some conditions | Patch in 1 week |
| 4.0–6.9 | **Medium** | Local or complex network attack | Patch in 30 days |
| 0.1–3.9 | **Low** | Restricted scope, limited impact | Opportunistic |

!!! warning "CVSS Is a Starting Point, Not a Decision"
    A CVSS 7.0 network-exploitable vulnerability with active exploits is more urgent than a CVSS 9.0 local vulnerability requiring admin access. Read the vector string, not just the number.

## Key CVSS Components Engineers Should Know

### Attack Vector (AV)

- `NETWORK (N)`: Most dangerous. Remotely exploitable.
- `ADJACENT (A)`: Same network segment (WiFi, VPN).
- `LOCAL (L)`: Local access required (privilege escalation risk).
- `PHYSICAL (P)`: Least dangerous. Physical access needed.

### Attack Complexity (AC)

- `LOW (L)`: Trivial to exploit, doesn't vary by target.
- `HIGH (H)`: Requires specific conditions, target-dependent.

### Privileges Required (PR)

- `NONE (N)`: Unauthenticated attack. Most dangerous.
- `LOW (L)`: User account required.
- `HIGH (H)`: Admin access required.

### User Interaction (UI)

- `NONE (N)`: No user action needed.
- `REQUIRED (R)`: Requires clicking link, opening email, etc.

**Decision Rule**: A CVSS 7.0 with `NETWORK/NONE` is more urgent than a CVSS 8.0 with `LOCAL/HIGH/REQUIRED`.

## Example: Interpreting CVSS Vectors

### Scenario 1: OpenSSL CVE

```text
CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H → 9.8 CRITICAL
```

- Network-exploitable, no auth, trivial
- **Decision**: Patch within 24 hours

### Scenario 2: Privilege Escalation in Sudo

```text
CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H → 7.8 HIGH
```

- Local access required, low-privilege user
- **Decision**: Patch within 1 week

### Scenario 3: Deserialization in Old Library

```text
CVSS:3.1/AV:N/AC:H/PR:N/UI:R/S:U/C:H/I:H/A:H → 6.9 MEDIUM
```

- Network, but requires user interaction (deserialize untrusted data)
- **Decision**: Patch within 30 days

## References

- [CVSS Specification](https://www.first.org/cvss/v3.1/specification-document)
- [NVD CVE Database](https://nvd.nist.gov/vuln)

---

*CVSS is a starting point, not the final decision. Context matters.*
