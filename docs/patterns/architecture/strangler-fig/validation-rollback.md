---
title: Validation and Rollback
description: >
  Test new components before production swap. Validation checklists, instant rollback strategies, and monitoring metrics for safe platform component replacement migrations.
---

# Validation and Rollback

Strategies for validating new components and rolling back safely if needed.

See [Platform Component Replacement](platform-component-replacement.md) for the core pattern overview.

!!! danger "Test Rollback BEFORE Production Swap"
    Your rollback plan is worthless until you test it. Practice the rollback in staging. Time how long it takes. Verify data integrity after rollback. Never assume rollback will work.

---

Before swapping components:

- [ ] **New component handles production load** (load test in staging)
- [ ] **Data replication is complete** (zero lag if applicable)
- [ ] **Compatibility layer tested** (both old and new work)
- [ ] **Rollback plan documented** (single command to revert)
- [ ] **Monitoring in place** (metrics for old AND new)
- [ ] **Alert thresholds set** (auto-rollback on errors)
- [ ] **Backup verified** (restore tested, not just backup)
- [ ] **Credentials rotated** (new component uses new secrets)

---

## Rollback Strategy

### Instant Rollback (Service Selector)

```bash
# Swap back to old component
kubectl patch service postgres -p '{"spec":{"selector":{"app":"postgres-old"}}}'

# Application reconnects to old component
# Total rollback time: < 30 seconds
```

### Data Rollback (If Data Changed)

```bash
# If new component modified data incompatibly
# Restore from snapshot taken before swap

# Option 1: Database snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier postgres-rollback \
  --db-snapshot-identifier pre-migration-snapshot

# Option 2: Volume snapshot
kubectl apply -f pvc-from-snapshot.yaml
```

**Critical**: Take snapshot **immediately before swap**, not hours before.

---

## Monitoring During Migration

### Metrics to Track

```yaml
# Old Component Metrics
- connection_count
- query_latency_p95
- error_rate
- disk_usage

# New Component Metrics
- connection_count (should match old)
- query_latency_p95 (should be ≤ old)
- error_rate (should be ≤ old)
- replication_lag (if applicable)

# Application Metrics
- request_success_rate (must stay stable)
- request_latency_p99 (must not spike)
- error_rate_5xx (must not increase)
```

### Alert Conditions

```yaml
# Auto-rollback triggers
- new_component_error_rate > old_component_error_rate * 1.5
- new_component_latency_p95 > old_component_latency_p95 * 2
- application_5xx_rate > baseline * 3
- new_component_unavailable for > 30 seconds
```

---

## Related Guides

- **[Platform Component Replacement](platform-component-replacement.md)** - Core pattern overview
- **[Compatibility Layers](compatibility-layers.md)** - Compatibility patterns
- **[Edge Cases and Comparison](edge-cases-comparison.md)** - When NOT to use, gotchas
