---
tags:
  - risk-management
  - risk-assessment
  - vulnerability-management
description: >-
  Risk assessment matrix for vulnerability prioritization. Impact, likelihood, and exploitability scoring with real-world examples and decision frameworks.
---

# Risk Assessment Matrix

Start by establishing baseline risk across three dimensions: impact, likelihood, and exploitability.

!!! tip "Assess All Three Dimensions"
    High impact with low likelihood is different risk than low impact with high likelihood. All three dimensions matter. Don't optimize for a single number.

## Risk Dimensions

```mermaid
graph TB
    subgraph impact["Impact"]
        I1["Critical: Complete compromise<br/>of core functionality or data"]
        I2["High: Major degradation<br/>or data exposure"]
        I3["Medium: Reduced functionality<br/>or limited exposure"]
        I4["Low: Cosmetic or<br/>edge-case impact"]
    end

    subgraph likelihood["Likelihood"]
        L1["High: In active exploitation<br/>or easy to weaponize"]
        L2["Medium: Known attack path<br/>requires some effort"]
        L3["Low: Theoretical or requires<br/>specific conditions"]
        L4["Minimal: Requires multiple<br/>preconditions or user error"]
    end

    subgraph exploitability["Exploitability"]
        E1["Trivial: No authentication,<br/>network-adjacent"]
        E2["Low: Requires basic tools<br/>or public PoC"]
        E3["Medium: Requires custom work<br/>or insider knowledge"]
        E4["High: Requires zero-day or<br/>sophisticated attack"]
    end

    %% Ghostty Hardcore Theme
    style I1 fill:#f92572,color:#1b1d1e
    style I2 fill:#fd971e,color:#1b1d1e
    style I3 fill:#a6e22e,color:#1b1d1e
    style I4 fill:#66d9ef,color:#1b1d1e

    style L1 fill:#f92572,color:#1b1d1e
    style L2 fill:#fd971e,color:#1b1d1e
    style L3 fill:#a6e22e,color:#1b1d1e
    style L4 fill:#66d9ef,color:#1b1d1e

    style E1 fill:#f92572,color:#1b1d1e
    style E2 fill:#fd971e,color:#1b1d1e
    style E3 fill:#a6e22e,color:#1b1d1e
    style E4 fill:#66d9ef,color:#1b1d1e

```

## Scoring Table

| Factor | 4 (Critical) | 3 (High) | 2 (Medium) | 1 (Low) |
|--------|-----------|----------|-----------|---------|
| **Impact** | Complete system failure, auth bypass, data loss | Major service degradation, sensitive data exposure | Partial functionality loss, limited exposure | Denial of service on rare path, information disclosure |
| **Likelihood** | Active exploits in wild, trivial to execute | Known exploitation path, tool availability | Proof of concept exists, requires effort | Theoretical only, multiple preconditions |
| **Exploitability** | No auth, network-adjacent, <5 minute PoC | Public PoC, basic tools needed | Custom work required, insider knowledge | Zero-day equivalent, extreme complexity |

## Risk Score Calculation

```text
Risk Score = (Impact × Likelihood × Exploitability) / 27 × Blast Radius
```

Where:

- Each factor: 1–4 points
- Result: 1–64 before blast radius adjustment
- **Blast Radius**: multiplier 0.2 to 5.0 based on affected systems

### Risk Score Interpretation

| Score | Label | Action |
|-------|-------|--------|
| 45+ | **CRITICAL** | Patch immediately, within 24 hours |
| 30-44 | **HIGH** | Patch this sprint, within 1 week |
| 15-29 | **MEDIUM** | Schedule for next planning cycle, within 30 days |
| 5-14 | **LOW** | Plan for regular maintenance, no urgency |
| <5 | **MINIMAL** | Track, monitor, address opportunistically |

## References

- [OWASP Risk Rating](https://owasp.org/www-project-risk-rating-manager/)
- [NIST Security Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5)

---

*Risk = Impact × Likelihood × Exploitability. Prioritize ruthlessly based on exposure.*
