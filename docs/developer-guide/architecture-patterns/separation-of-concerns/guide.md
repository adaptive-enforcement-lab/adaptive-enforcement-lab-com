---
title: Separation of Concerns Usage Guide
description: >-
  When to apply separation of concerns, common mistakes to avoid,
  and real-world examples of the pattern in production systems.
---

# Separation of Concerns Usage Guide

## When to Apply This Pattern

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

**Always:**

- CLI tools
- API handlers
- Workflow orchestrators
- Service layers

**Especially when:**

- Multiple concerns in one function
- Testing requires external systems
- Changes ripple across unrelated code
- New team members struggle to understand flow

---

## Common Mistakes

### Mistake 1: Over-Separation

```go
// Too granular
func getFirstName(user User) string { return user.FirstName }
func getLastName(user User) string { return user.LastName }
func formatName(first, last string) string { return first + " " + last }

// Reasonable
func getFullName(user User) string {
    return fmt.Sprintf("%s %s", user.FirstName, user.LastName)
}
```

Separation is about logical concerns, not individual operations.

### Mistake 2: Premature Abstraction

Don't separate concerns that don't exist yet. Wait until you have two different concerns before splitting.

### Mistake 3: Wrong Boundaries

```go
// Bad: cuts across natural boundaries
func parseAndValidate(path string) (*Config, error)  // Parser + validator mixed

// Good: natural boundaries
func parse(path string) (*Config, error)
func validate(config *Config) error
```

---

## Real-World Example

See [Go CLI Architecture](../../go-cli-architecture/command-architecture/orchestrator-pattern.md) for full implementation of the orchestrator pattern.

---

## Related Patterns

- **[Pattern Overview](index.md):** Core concepts and CLI orchestrator pattern
- **[Implementation Techniques](implementation.md):** Testing, interfaces, dependency injection
- **[Hub and Spoke](../hub-and-spoke/index.md):** Distributed version of orchestration
- **[Fail Fast](../../error-handling/fail-fast/index.md):** Error handling at boundaries
- **[Prerequisite Checks](../../error-handling/prerequisite-checks/index.md):** Validation separation

---

*Each component does one thing well. Changes are isolated. Tests run in milliseconds. The system is maintainable.*
