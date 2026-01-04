---
description: >-
  Order prerequisite checks by cost: configuration first, then tools, local state, remote access, and expensive resource queries last for fastest failure detection.
---

# Check Ordering

Order checks from cheapest to most expensive.

!!! tip "Key Insight"
    Fail on cheap checks before running expensive ones. Configuration errors should be caught in milliseconds, not after API calls.

---

## Cost-Based Ordering

```mermaid
flowchart TD
    A[1. Configuration] --> B[2. Tools]
    B --> C[3. Local State]
    C --> D[4. Remote Access]
    D --> E[5. Remote State]
    E --> F[6. Resource Availability]

    %% Ghostty Hardcore Theme
    style A fill:#a7e22e,color:#1b1d1e
    style B fill:#a7e22e,color:#1b1d1e
    style C fill:#fd971e,color:#1b1d1e
    style D fill:#fd971e,color:#1b1d1e
    style E fill:#f92572,color:#1b1d1e
    style F fill:#f92572,color:#1b1d1e

```

---

## Order by Cost

| Order | Category | Cost | Example |
| ------- | ---------- |------ | --------- |
| 1 | Configuration | Free | Check required fields are set |
| 2 | Tools | Cheap | Check binaries exist |
| 3 | Local State | Cheap | Check local files exist |
| 4 | Remote Access | Medium | Test API authentication |
| 5 | Remote State | Medium | Check remote resources exist |
| 6 | Resources | Expensive | Check quotas, capacity |

---

## Why Order Matters

Fail on cheap checks before running expensive ones. Benefits:

- **Faster feedback** - Configuration errors caught in milliseconds
- **Reduced costs** - No API calls if local checks fail
- **Better UX** - Users see the simplest fixes first
