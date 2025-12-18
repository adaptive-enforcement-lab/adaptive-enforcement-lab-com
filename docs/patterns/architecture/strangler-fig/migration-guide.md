---
title: Migration Guide
description: >-
  Eight-phase checklist from shadow mode to decommission. Real-world timeline, common pitfalls, and pre-migration validation criteria for zero-risk migrations.
---

# Migration Guide

Strangler Fig migrations follow eight phases over 8 weeks. Each phase has validation criteria. Don't proceed to next phase until current phase is stable.

!!! tip "Migration Pattern"
    This guide covers the Strangler Fig pattern for incremental system migration. Review all sections for complete implementation strategy.

---

## Migration Checklist

| Phase | Actions | Validation |
| ------- | --------- | ------------ |
| **1. Shadow** | New system runs in background | Mismatch logging, zero production impact |
| **2. Dual Write** | Write to both databases | Data consistency checks |
| **3. 1% Traffic** | Route 1% to new system | Error rates, latency P95 |
| **4. 5% Traffic** | Increase to 5% | Monitor for 24 hours |
| **5. 10% Traffic** | Increase to 10% | Load testing, resource usage |
| **6. 50% Traffic** | Half traffic on new | Full production validation |
| **7. 100% Traffic** | All traffic on new | Legacy in standby for 1 week |
| **8. Decommission** | Remove legacy | Data migration complete |

Don't skip phases. Each validates the next.

---

## Real-World Timeline

### Weeks 1-2: Shadow Mode

- New system processes requests in background
- Logs mismatches with legacy
- Fix discrepancies
- **Goal**: 99.9% match rate

No production traffic to new system yet. Shadow mode finds bugs without risk.

### Week 3: 1% Traffic

- Route 1% production traffic
- Monitor error rates, latency
- Fix bugs discovered under real load

Real users hit new system. First chance to validate under production conditions.

### Week 4: 10% Traffic

- Increase to 10%
- Load test at scale
- Optimize resource usage

Enough traffic to stress test. Too little to cause catastrophic failure.

### Weeks 5-6: 50% Traffic

- Half production load
- Performance tuning
- Cost analysis

This is the confidence phase. If 50% works for 2 weeks, 100% will work.

### Week 7: 100% Traffic

- All traffic on new system
- Legacy in standby
- Monitor for regressions

Don't delete legacy yet. Keep it running for instant rollback.

### Week 8: Decommission

- Remove legacy system
- Delete legacy database
- Update documentation

Migration complete. Legacy system retired.

---

## Common Pitfalls

### Pitfall 1: No Rollback Plan

Always have a kill switch. Feature flag or traffic router that can shift back instantly.

**Fix**: Deploy feature flag infrastructure before migration starts. Test rollback in staging.

### Pitfall 2: Skipping Shadow Mode

Don't route production traffic to unvalidated code. Shadow first.

**Fix**: Run new system in shadow mode for minimum 1 week. Fix all mismatches before routing real traffic.

### Pitfall 3: Ignoring Data Consistency

Dual writes can fail. Monitor lag between legacy and new databases.

**Fix**: Implement reconciliation jobs that detect and fix data drift. Alert on lag >100ms.

### Pitfall 4: Moving Too Fast

Don't jump from 1% to 100%. Increase gradually. Monitor each phase.

**Fix**: Spend at least 24 hours at each phase. If metrics degrade, don't proceed.

---

## Pre-Migration Checklist

Before starting:

- [ ] Feature flag system deployed and tested
- [ ] Shadow mode infrastructure in place
- [ ] Monitoring dashboards created (legacy vs new)
- [ ] Alerting rules configured
- [ ] Rollback runbook documented
- [ ] On-call rotation briefed
- [ ] Database backup strategy verified
- [ ] Load testing plan documented
- [ ] Communication plan for stakeholders

Don't start without this foundation.

---

## Success Criteria

Migration is complete when:

1. New system handles 100% traffic for 1 week
2. Error rates ≤ legacy baseline
3. Latency P95 ≤ legacy baseline
4. Resource usage within budget
5. Legacy system removed
6. Documentation updated
7. Post-mortem completed

---

## Post-Migration Cleanup

After decommissioning legacy:

- Remove feature flags (dead code)
- Delete legacy database
- Update runbooks and documentation
- Archive metrics dashboards (historical reference)
- Remove dual-write code paths
- Simplify routing logic

Don't leave migration scaffolding in production forever.

---

## Related Patterns

- **[Implementation Strategies](implementation.md)** - Feature flags and shadow mode
- **[Traffic Routing](traffic-routing.md)** - Percentage and user-based routing
- **[Monitoring and Rollback](monitoring.md)** - Observability and safety

---

*Week 1: Shadow mode caught edge cases. Week 3: 1% traffic revealed load balancer bug. Week 5: 50% traffic ran stable. Week 8: Legacy decommissioned. Migration complete. Zero production incidents. Post-mortem showed careful phasing prevented catastrophic failure.*
