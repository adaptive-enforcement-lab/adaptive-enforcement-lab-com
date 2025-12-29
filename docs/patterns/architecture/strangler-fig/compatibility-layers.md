---
title: Compatibility Layers
description: >
  Maintain compatibility during platform component replacement with service abstraction, API gateways, conversion webhooks, and database views for zero-downtime migrations.
---

# Compatibility Layers

Patterns for maintaining compatibility during platform component replacement.

See [Platform Component Replacement](platform-component-replacement.md) for the core pattern overview.

!!! warning "Critical: Compatibility Layer Required"
    Never swap components without a compatibility layer. The compatibility layer allows instant rollback and ensures both old and new components can serve traffic during validation.

---

## Pattern 1: Service Abstraction

```yaml
# Service always named "database"
# Selector points to old OR new backend
# Application never changes connection string

apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  selector:
    component: postgres  # Tag both old and new with this
```

## Pattern 2: API Gateway

```yaml
# Gateway routes to old OR new API
# Old: /api/v1/* → legacy-backend
# New: /api/v1/* → new-backend
# Switch routing without changing client URLs
```

## Pattern 3: Conversion Webhook

```yaml
# Kubernetes CRD conversion webhook
# Clients submit v1alpha1
# Webhook converts to v1
# Controller processes v1
# Clients unaware of version change
```

## Pattern 4: Database Views

```sql
-- Old table: users_old
-- New table: users_new
-- View maintains compatibility

CREATE VIEW users AS
  SELECT * FROM users_new
  UNION ALL
  SELECT * FROM users_old WHERE id NOT IN (SELECT id FROM users_new);
```

---

## Related Guides

- **[Platform Component Replacement](platform-component-replacement.md)** - Core pattern overview
- **[Platform Component Examples](platform-component-examples.md)** - Real-world migration examples
- **[Validation and Rollback](validation-rollback.md)** - Testing and rollback strategies
