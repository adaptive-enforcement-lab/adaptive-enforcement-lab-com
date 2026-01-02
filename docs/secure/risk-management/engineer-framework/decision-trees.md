---
tags:
  - risk-management
  - decision-framework
  - patch-management
description: >-
  Decision trees for vulnerability remediation. Patch-now vs. later, mitigate vs. accept vs. transfer, and emergency vs. standard patching workflows.
---

# Decision Trees

!!! tip "Use Decision Trees to Avoid Analysis Paralysis"
    When a CVE drops at 2am, you don't have time for debate. Pre-made decision trees eliminate decision fatigue. Follow the flowchart. Document exceptions later.

## Decision Tree 1: Patch Now vs. Later

```mermaid
flowchart TD
    A["Vulnerability Discovered"] --> B{"Exploit<br/>In The Wild?"}

    B -->|Yes| C["PATCH IMMEDIATELY<br/>Target: 4-24 hours"]
    B -->|No| D{"CVSS Score<br/>≥ 8.0?"}

    D -->|Yes| E{"Blast Radius<br/>≥ 50% Systems?"}
    E -->|Yes| F["URGENT<br/>Target: 24-72 hours"]
    E -->|No| G["HIGH<br/>Target: 1 week"]

    D -->|No| H{"Affects<br/>Production?"}
    H -->|Yes| I["MEDIUM<br/>Target: 30 days"]
    H -->|No| J["LOW<br/>Next maintenance window"]

    style A fill:#66d9ef,color:#1b1d1e
    style B fill:#fd971e,color:#1b1d1e
    style C fill:#f92572,color:#1b1d1e
    style D fill:#fd971e,color:#1b1d1e
    style E fill:#fd971e,color:#1b1d1e
    style F fill:#f92572,color:#1b1d1e
    style G fill:#fd971e,color:#1b1d1e
    style H fill:#fd971e,color:#1b1d1e
    style I fill:#a6e22e,color:#1b1d1e
    style J fill:#66d9ef,color:#1b1d1e
```

**Implementation Checklist for IMMEDIATE**:

- [ ] Alert all on-call engineers
- [ ] Start remediation in parallel environments
- [ ] Identify rollback plan
- [ ] Do NOT wait for change request approval (this is the exception)
- [ ] Notify leadership once mitigation is in progress
- [ ] Write incident report post-patch

## Decision Tree 2: Mitigate vs. Accept vs. Transfer

```mermaid
flowchart TD
    A["Risk Identified"] --> B{"Can be<br/>Patched?"}

    B -->|Yes| C{"Patch Cost<br/>Acceptable?"}
    C -->|Yes| D["PATCH<br/>Follow patch timeline"]
    C -->|No| E{"Can Compensate<br/>Controls Exist?"}

    B -->|No| F{"Can Compensate<br/>Controls Exist?"}
    F -->|Yes| G["MITIGATE<br/>WAF rule, network isolation, etc."]
    F -->|No| H{"Can Transfer<br/>Insurance/SLA?"}

    E -->|Yes| G
    E -->|No| H

    H -->|Yes| I["TRANSFER<br/>Update contracts, document risk"]
    H -->|No| J["ACCEPT<br/>Document risk, set review date"]

    style A fill:#66d9ef,color:#1b1d1e
    style B fill:#fd971e,color:#1b1d1e
    style C fill:#fd971e,color:#1b1d1e
    style D fill:#a6e22e,color:#1b1d1e
    style E fill:#fd971e,color:#1b1d1e
    style F fill:#fd971e,color:#1b1d1e
    style G fill:#fd971e,color:#1b1d1e
    style H fill:#fd971e,color:#1b1d1e
    style I fill:#a6e22e,color:#1b1d1e
    style J fill:#fd971e,color:#1b1d1e
```

## Decision Tree 3: Emergency vs. Standard Patching

```mermaid
flowchart TD
    A["Patch Ready"] --> B{"Risk Score<br/>≥ 40?"}

    B -->|Yes| C["EMERGENCY PATH"]
    C --> D["1. Test in staging only<br/>30 minutes max"]
    D --> E["2. Deploy with canary<br/>5% → 25% → 100%"]
    E --> F["3. Monitor metrics closely<br/>Error rate, latency"]
    F --> G["4. Rollback plan ready<br/>One-click revert"]

    B -->|No| H["STANDARD PATH"]
    H --> I["1. Full test suite pass<br/>Unit + integration"]
    I --> J["2. Staging validation<br/>24 hours minimum"]
    J --> K["3. Change request approval"]
    K --> L["4. Deploy in standard window<br/>Next deployment slot"]

    style A fill:#66d9ef,color:#1b1d1e
    style B fill:#fd971e,color:#1b1d1e
    style C fill:#f92572,color:#1b1d1e
    style D fill:#f92572,color:#1b1d1e
    style E fill:#f92572,color:#1b1d1e
    style F fill:#f92572,color:#1b1d1e
    style G fill:#f92572,color:#1b1d1e
    style H fill:#a6e22e,color:#1b1d1e
    style I fill:#a6e22e,color:#1b1d1e
    style J fill:#a6e22e,color:#1b1d1e
    style K fill:#a6e22e,color:#1b1d1e
    style L fill:#a6e22e,color:#1b1d1e
```

---

*Fast decisions save time. Use decision trees to avoid analysis paralysis.*
