# Operator Manual

Configure and run secure automation infrastructure.

This manual covers the **operational procedures** for setting up and managing automation systems. While the [Developer Guide](../developer-guide/index.md) focuses on building systems, this manual focuses on running them.

---

## GitHub Actions

Enterprise-grade GitHub automation with centralized authentication and cross-repository operations.

<div class="grid cards" markdown>

-   :material-key:{ .lg .middle } **GitHub App Setup**

    ---

    Create and configure organization-level GitHub Apps for secure, centralized authentication.

    [:octicons-arrow-right-24: Setup Guide](github-actions/github-app-setup/index.md)

-   :material-connection:{ .lg .middle } **Actions Integration**

    ---

    Generate and use tokens in workflows with proper scoping and security.

    [:octicons-arrow-right-24: Integration Guide](github-actions/actions-integration/index.md)

-   :material-file-sync:{ .lg .middle } **Use Cases**

    ---

    Real-world patterns for cross-repository automation.

    [:octicons-arrow-right-24: File Distribution](github-actions/use-cases/file-distribution/index.md)

</div>

---

## Argo Events

Event-driven workflow automation for Kubernetes. Deploy, configure, and troubleshoot Argo Events in production.

<div class="grid cards" markdown>

-   :material-cog:{ .lg .middle } **Setup Guide**

    ---

    Configure EventSource, EventBus, and Sensor components for production.

    [:octicons-arrow-right-24: Setup Guide](argo-events/setup/index.md)

-   :material-bug:{ .lg .middle } **Troubleshooting**

    ---

    Debug event flows, identify failures, and resolve common issues.

    [:octicons-arrow-right-24: Troubleshooting Guide](argo-events/troubleshooting/index.md)

-   :material-server-network:{ .lg .middle } **High Availability**

    ---

    Deploy redundant, production-grade Argo Events infrastructure.

    [:octicons-arrow-right-24: HA Guide](argo-events/reliability/high-availability.md)

</div>

---

## What's Covered

### GitHub App Setup

- Creating organization-level GitHub Apps
- Storing credentials securely
- Permission patterns and scoping
- Installation and maintenance

### Actions Integration

- Token generation with `actions/create-github-app-token`
- Workflow patterns for cross-repo operations
- Error handling and troubleshooting
- Performance optimization

### Use Cases

- **File Distribution** - Sync files across multiple repositories
- Three-stage workflow pattern (Discovery → Distribution → Summary)
- Idempotent operations for safe reruns

### Argo Events

- EventSource configuration for external systems
- EventBus deployment with JetStream
- Sensor configuration for workflow triggers
- High availability and production deployment
- Troubleshooting event flows and failures

---

## Coming Soon

!!! info "Expanding Coverage"

    Future additions to the Operator Manual:

    - **Argo Workflows** - CronWorkflow deployment and scheduling
    - **Monitoring** - Observability and alerting setup
    - **Security** - RBAC, network policies, and secrets management

    See the [Roadmap](../roadmap.md) for the full list.

---

*Running automation that doesn't wake you up at 3am.*
