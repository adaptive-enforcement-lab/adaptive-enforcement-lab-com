# Developer Guide

Build resilient, maintainable automation systems.

!!! abstract "Guide Purpose"
    Patterns and architecture for reliable automation at scale. While the Operator Manual focuses on configuring and running systems, this guide focuses on building them well.

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

-   :material-language-go:{ .lg .middle } **Go CLI Architecture**

    ---

    Build Kubernetes-native orchestration CLIs.

    [:octicons-arrow-right-24: Go CLI Architecture](go-cli-architecture/index.md)

-   :material-cloud-sync:{ .lg .middle } **Argo Events**

    ---

    Event-driven workflow automation for Kubernetes.

    [:octicons-arrow-right-24: Argo Events](argo-events/index.md)

-   :material-state-machine:{ .lg .middle } **Argo Workflows**

    ---

    Production patterns for workflow templates and orchestration.

    [:octicons-arrow-right-24: Argo Workflows](argo-workflows/index.md)

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
| Go CLI | [Framework Selection](go-cli-architecture/framework-selection/index.md) | Choose CLI frameworks and config |
| Go CLI | [Kubernetes Integration](go-cli-architecture/kubernetes-integration/index.md) | client-go patterns and RBAC |
| Go CLI | [Command Architecture](go-cli-architecture/command-architecture/index.md) | Orchestrator and subcommand design |
| Go CLI | [Packaging](go-cli-architecture/packaging/index.md) | Container builds and Helm charts |
| Go CLI | [Testing](go-cli-architecture/testing/index.md) | Unit, integration, and E2E testing |
| Argo Events | [Event Routing](argo-events/routing/index.md) | Filtering, transformations, and multi-trigger |
| Argo Events | [Reliability Patterns](argo-events/reliability/index.md) | Retries, dead letter queues, and backpressure |
| Argo Workflows | [WorkflowTemplates](argo-workflows/templates/index.md) | Reusable templates with RBAC and volumes |
| Argo Workflows | [Concurrency](argo-workflows/concurrency/index.md) | Mutex, semaphores, and TTL strategies |
| Argo Workflows | [Composition](argo-workflows/composition/index.md) | Parent/child and cross-workflow patterns |
| Argo Workflows | [Scheduled](argo-workflows/scheduled/index.md) | CronWorkflow and GitHub integration |

---

*Building automation that survives contact with production.*
