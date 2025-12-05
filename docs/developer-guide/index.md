# Developer Guide

Build resilient, maintainable automation systems.

This guide covers patterns and architecture for reliable automation at scale. While the Operator Manual focuses on configuring and running systems, this guide focuses on building them well.

---

## Start Here

<div class="grid cards" markdown>

-   :material-compass:{ .lg .middle } **Pattern Selection Guide**

    ---

    Not sure which pattern to use? Start with the decision matrix.

    [:octicons-arrow-right-24: Choose a Pattern](pattern-selection-guide/index.md)

</div>

---

## By Category

<div class="grid cards" markdown>

-   :material-alert-circle:{ .lg .middle } **Error Handling**

    ---

    Detect, report, and recover from failures.

    [:octicons-arrow-right-24: Error Handling Patterns](error-handling/index.md)

-   :material-lightning-bolt:{ .lg .middle } **Efficiency Patterns**

    ---

    Avoid unnecessary work and ensure safe retries.

    [:octicons-arrow-right-24: Efficiency Patterns](efficiency-patterns/index.md)

-   :material-sitemap:{ .lg .middle } **Workflow Architecture**

    ---

    Structure scalable CI/CD workflows.

    [:octicons-arrow-right-24: Workflow Architecture](workflow-architecture/index.md)

</div>

---

## All Patterns

| Category | Pattern | Purpose |
|----------|---------|---------|
| Error Handling | [Fail Fast](error-handling/fail-fast/index.md) | Stop immediately on unrecoverable errors |
| Error Handling | [Prerequisite Checks](error-handling/prerequisite-checks/index.md) | Validate all preconditions upfront |
| Error Handling | [Graceful Degradation](error-handling/graceful-degradation/index.md) | Fall back to safer states |
| Efficiency | [Idempotency](efficiency-patterns/idempotency/index.md) | Make operations safe to retry |
| Efficiency | [Work Avoidance](efficiency-patterns/work-avoidance/index.md) | Skip unnecessary operations |
| Architecture | [Three-Stage Design](workflow-architecture/three-stage-design.md) | Discovery, execution, summary |
| Architecture | [Matrix Distribution](workflow-architecture/matrix-distribution/index.md) | Parallel multi-target operations |

---

*Building automation that survives contact with production.*
