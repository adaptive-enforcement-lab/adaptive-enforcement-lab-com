# Developer Guide

Build resilient, maintainable automation systems.

This guide covers the **design principles** and **implementation patterns** that make automation reliable at scale. While the Operator Manual focuses on configuring and running systems, this guide focuses on building them well.

---

## Engineering Practices

Tactical patterns and strategic principles for automation engineering.

<div class="grid cards" markdown>

-   :material-puzzle:{ .lg .middle } **Patterns**

    ---

    Concrete implementations with code examples.

    [:octicons-arrow-right-24: Implementation Patterns](engineering-practices/patterns/index.md)

-   :material-compass:{ .lg .middle } **Principles**

    ---

    Decision-making frameworks and architectural guidance.

    [:octicons-arrow-right-24: Design Principles](engineering-practices/principles/index.md)

</div>

---

## Patterns vs Principles

| Aspect | Patterns | Principles |
|--------|----------|------------|
| **Level** | Implementation | Architecture |
| **Output** | Code snippets | Decision trees |
| **Question** | "How do I...?" | "Should I...?" |
| **Example** | Upsert pattern in bash | When to fail fast vs degrade |

Patterns are the *how*. Principles are the *why* and *when*.

---

## What's Covered

### Patterns

- **Idempotency** - Make operations safe to retry
- **Caching** - Avoid redundant work
- **Work Avoidance** - Skip unnecessary operations

### Principles

- **Graceful Degradation** - Fail to safer states
- **Fail Fast** - Detect problems early
- **Prerequisite Checks** - Validate before executing

---

*Building automation that survives contact with production.*
