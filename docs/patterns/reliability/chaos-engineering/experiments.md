---
title: Chaos Experiment Catalog
description: >-
  Chaos experiment catalog overview. Pod deletion, network latency, memory pressure, and dependency failure experiment categories.
tags:
  - chaos-engineering
  - experiments
  - kubernetes
  - scenarios
---
# Chaos Experiment Catalog

Each experiment follows this structure:

1. **Configuration** - Complete YAML
2. **Expected behavior** - What should happen
3. **Success criteria** - How to know it worked
4. **Validation queries** - Prometheus/observability checks
5. **Rollback procedure** - How to stop it

!!! success "Start Small, Scale Systematically"
    Begin with single-pod experiments in staging. Progress to production only after validating success criteria, rollback procedures, and observability coverage.

---

## Experiment Categories

### Pod-Level Experiments

Pod deletion and crash loop testing to validate application recovery and orchestration behavior.

**[View Pod Experiments →](pod-experiments.md)**

Key scenarios:

- Pod deletion (crash loop testing)
- Graceful shutdown validation
- Readiness probe behavior
- Replica replacement timing

---

### Network Experiments

Network latency injection and dependency timeout testing to validate circuit breakers and fallback patterns.

**[View Network Experiments →](network-experiments.md)**

Key scenarios:

- Database latency injection
- Circuit breaker validation
- Cache fallback behavior
- Timeout handling

---

### Resource Experiments

Memory pressure and CPU stress testing to validate resource limit enforcement and graceful degradation.

**[View Resource Experiments →](resource-experiments.md)**

Key scenarios:

- Memory pressure testing
- OOM kill behavior
- Garbage collection under stress
- Load shedding patterns

---

### Dependency Experiments

Multi-service resilience testing to validate circuit breakers, fallback patterns, and graceful degradation.

**[View Dependency Experiments →](dependency-experiments.md)**

Key scenarios:

- External API failures
- Circuit breaker patterns
- Fallback responses
- Automatic recovery

---

## Quick Start

All experiments follow the same execution pattern:

```bash
# Apply chaos experiment
kubectl apply -f experiment.yaml

# Monitor system behavior
kubectl logs -f -n chaos-testing deployment/chaos-controller-manager

# Verify success criteria with Prometheus queries
# (See individual experiment pages for specific queries)

# Rollback if needed
kubectl delete -f experiment.yaml
```

## Related Documentation

- **[Back to Overview](index.md)** - Chaos engineering introduction
- **[Validation Patterns](validation.md)** - SLI monitoring and testing
- **[Operations](operations.md)** - Running experiments safely
