---
title: Edge Cases and Comparison
description: >
  When NOT to use component replacement, comparison with traffic routing, common gotchas and solutions.
---

# Edge Cases and Comparison

Understanding when component replacement does not apply and common pitfalls to avoid.

See [Platform Component Replacement](platform-component-replacement.md) for the core pattern overview.

!!! warning "Know When NOT to Use Component Replacement"
    Component replacement is not a universal solution. If users expect the old API, if schema changes are breaking, or if data cannot be replicated, use a different migration strategy.

---

| Scenario | Problem | Use Instead |
| -------- | ------- | ----------- |
| **User-facing API changes** | Users expect old API | Traffic routing with gradual rollout |
| **Breaking schema changes** | Old and new incompatible | Blue-green deployment with cutover |
| **Stateful data migration** | Data can't be replicated | Maintenance window with downtime |
| **Cost-prohibitive** | Can't run both components | Phased cutover during low-traffic window |

---

## Comparison: Traffic Routing vs Component Replacement

| Aspect | Traffic Routing | Component Replacement |
| ------ | --------------- | ---------------------- |
| **Use Case** | User-facing APIs, features | Infrastructure, backing services |
| **Mechanism** | Route percentage of traffic | Swap component references |
| **Rollback** | Decrease traffic to 0% | Change selector/reference back |
| **Monitoring** | Compare old vs new metrics | Compare old vs new metrics |
| **Complexity** | Routing layer required | Compatibility layer required |
| **User Impact** | Gradual (some users on old, some on new) | Instant (all users on new after swap) |
| **Best For** | A/B testing, feature flags | Database migrations, operator upgrades |

**Not mutually exclusive**: You can use traffic routing for APIs and component replacement for databases **in the same migration**.

---

## Edge Cases and Gotchas

### Gotcha 1: Connection Pooling

**Problem**: Application maintains connection pool to old database. After swap, pool still points to old instance.

**Solution**:

```yaml
# Force connection pool refresh
# Option 1: Restart pods (graceful)
kubectl rollout restart deployment/app

# Option 2: Connection pool TTL
# Configure connection max lifetime < migration window
pool.maxLifetimeSeconds: 300  # 5 minutes
```

### Gotcha 2: DNS Caching

**Problem**: Service DNS entry cached by application. After swap, app still resolves to old IP.

**Solution**:

```yaml
# Short TTL on Service DNS
# Configure in CoreDNS
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
data:
  Corefile: |
    .:53 {
      ttl 30  # 30 second TTL
    }
```

### Gotcha 3: Hard-Coded References

**Problem**: Application has hard-coded database hostname (not Service name).

**Solution**:

```bash
# Identify hard-coded references BEFORE migration
grep -r "postgres-old" ./config/
grep -r "10.0.1.5" ./config/  # IP address hard-coded

# Update all references to Service name
# Service name stays constant, backend changes
```

### Gotcha 4: Partial Writes During Swap

**Problem**: Write started on old component, completed on new component. Data inconsistency.

**Solution**:

```yaml
# Use transactional writes
# Ensure writes are atomic
# Database handles in-flight transactions during failover
postgresql:
  synchronous_commit: on
  max_wal_senders: 10
```

---

## Migration Timeline Example

Real-world PostgreSQL HA migration:

| Week | Activity | Downtime |
| ---- | -------- | -------- |
| Week 1 | Deploy new cluster, set up replication | 0 min |
| Week 2 | Monitor replication lag, validate data consistency | 0 min |
| Week 3 | Test read queries against new cluster | 0 min |
| Week 4 | **Swap Service to new cluster** (Friday 2 AM) | **0 min** |
| Week 5 | Monitor production traffic on new cluster | 0 min |
| Week 6 | Remove old cluster | 0 min |

**Total downtime**: 0 minutes
**Rollback windows**: Week 4-5 (instant rollback via Service selector)
**Production incident**: 0

---

## Related Patterns

- **[Traffic Routing](traffic-routing.md)** - Use for user-facing APIs instead
- **[Monitoring and Rollback](monitoring.md)** - Metrics and alert thresholds
- **[Idempotency](../../efficiency/idempotency/index.md)** - Ensure operations can be retried during swap
- **[Graceful Degradation](../../error-handling/graceful-degradation/index.md)** - Fallback to old component on errors

---

*The new PostgreSQL cluster ran for 3 weeks in parallel. Replication lag stayed under 100ms. The Service selector changed at 2 AM on a Friday. Applications reconnected within 30 seconds. Error rates stayed flat. After 2 weeks of monitoring, the old cluster was decommissioned. Total downtime: zero minutes.*
